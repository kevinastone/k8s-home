# Cluster Bootstrap Plan (`BOOTSTRAP.md`)

This document outlines the plan to replace the Ansible `cilium` and `fluxcd` bootstrap roles (`~/Documents/ansible-playbook/roles/{cilium,fluxcd}`) with an in-repository interactive **Nushell** bootstrap script tailored to this repository's Nix Flake environment, 1Password CLI (`op`), and Flux Operator architecture.

______________________________________________________________________

## 1. Scope & Boundary with Ansible

**Remains in Ansible (`~/Documents/ansible-playbook/playbooks/k8s.yaml`):**

- Node OS prerequisites (`swap_off`, `cluster_ip` / HAProxy + Keepalived, kernel modules, sysctls, apt packages).
- `kubeadm init` (`roles/kubernetes`), control-plane untainting, and worker label assignment.
- Copying/fetching `/etc/kubernetes/admin.conf` so the operator has a working `KUBECONFIG` pointing at `https://192.168.120.3:16443`.

**Moves to `k8s-home` (`bootstrap/`):**

- Pre-flight validation (cluster connectivity, node presence, 1Password CLI authentication).
- Core namespace creation (`flux-system`, `prometheus`).
- Bootstrap secret injection directly from **1Password** via `op read` / `op inject` (`sops-age` and `fluxcd-sync`).
- Bootstrapping core Helm releases via a **Nushell** script (`bootstrap.nu`) that natively parses existing Flux `HelmRelease` YAML manifests (`open ... | get spec...`) and pipes `.spec.values` directly into `helm upgrade --install` (zero duplication, no `yq` or `helmfile` needed).

______________________________________________________________________

## 2. Architecture & Design Decisions

### A. Tooling: Nix DevShell + Nushell (`nu`) + `helm` + `op`

Using **Nushell** (already used in this repository for [`monitoring/grafana/scripts/build_dashboards.nu`](./monitoring/grafana/scripts/build_dashboards.nu) and formatted with `nufmt` via `nix fmt`) eliminates several external dependencies because Nushell natively parses and emits YAML (`open` / `to yaml`), handles structured records/tables, and includes built-in interactive prompts (`input`):

- `nushell` (`nu`) — parses `HelmRelease` YAML manifests natively and drives the interactive workflow
- `kubectl` and `kubernetes-helm` (`helm`) — already present in `flake.nix`
- `_1password-cli` (`op`) — for reading/injecting secrets from the `Homelab` 1Password vault
- `bootstrap-cluster` — packaged via a shared `writeNuBin` helper in `nix/` (matching `build-dashboards` in [`monitoring/grafana/default.nix`](./monitoring/grafana/default.nix#L22-L44))

### B. Secret Injection via 1Password (`op inject`)

Currently, `roles/fluxcd/vars/main.yaml` stores two bootstrap secrets in `ansible-vault`:

1. **`fluxcd-sync` (`flux-system`)**: SSH deploy key (`identity`, `identity.pub`, `known_hosts`) for `ssh://git@github.com/kevinastone/k8s-home`, stored in 1Password at `op://Homelab/FluxCD Deploy Key/{private key,public key}`.
1. **`sops-age` (`flux-system`)**: The SOPS Age private key (`age.agekey`) matching public key `age1dlmufx4en4fawc9phl2s7kx89347u0p3qds8rg3yjf5l3agnt48q4zvffd` (`.sops.yaml`), stored in 1Password at `op://Homelab/age.agekey/credential`. Flux uses this key to decrypt SOPS-encrypted secrets in the repository (`backends/one-password/secrets/*.encrypted`, `system/fluxcd/webhook/secrets/*.encrypted`, etc.).

> [!TIP]
> **Why SSH Deploy Key Works Great Here:**
> A repository-scoped GitHub SSH Deploy Key (`ssh://git@github.com/kevinastone/k8s-home`) is read-only, scoped strictly to this single repository (unlike a classic PAT), does not require a GitHub Organization (unlike a GitHub App), and doesn't expire annually like fine-grained PATs. Note that 1Password SSH key items require `?ssh-format=openssh` when reading the `private key` field via `op` so it exports in standard OpenSSH PEM format.

#### Proposed 1Password Template (`bootstrap/secrets.yaml.tpl`)

Committed safely to Git (contains only `op://` secret references, no sensitive data):

```yaml
---
apiVersion: v1
kind: Secret
metadata:
  name: sops-age
  namespace: flux-system
stringData:
  age.agekey: |
    {{ op://Homelab/age.agekey/credential }}
---
apiVersion: v1
kind: Secret
metadata:
  name: fluxcd-sync
  namespace: flux-system
stringData:
  identity: |
    {{ op://Homelab/FluxCD Deploy Key/private key?ssh-format=openssh }}
  identity.pub: |
    {{ op://Homelab/FluxCD Deploy Key/public key }}
  known_hosts: |
    github.com ecdsa-sha2-nistp256 AAAAE2VjZHNhLXNoYTItbmlzdHAyNTYAAAAIbmlzdHAyNTYAAABBBEmKSENjQEezOmxkZMy7opKgwFB9nkt5YRrYMjNuG5N87uRgg6CLrbo5wAdT/y6v0mKV0U2w0WZ2YB/++Tpockg=
```

### C. Zero-Duplication Helm Bootstrapping in Nushell

Previously, the Ansible `cilium` role (`roles/cilium/tasks/main.yaml`) had to inject a temporary `bootstrap_override` disabling `serviceMonitor.enabled` because the `ServiceMonitor` CRD wasn't installed yet:

```yaml
    bootstrap_override:
      prometheus:
        serviceMonitor:
          enabled: false
      operator:
        prometheus:
          serviceMonitor:
             enabled: false
```

With a clean `apply_helmrelease` function in Nushell:

1. **Native YAML Parsing**: Nushell's `open $file` parses each Flux `HelmRelease` directly into a record, extracts `.metadata.name`, `.spec.chart.spec.url`, `.spec.chart.spec.ref.tag`, and `.spec.values`, and pipes `($values | to yaml)` straight into `helm upgrade --install --values -`:
   - [`crds/prometheus/helmrelease.yaml`](./crds/prometheus/helmrelease.yaml) (`prometheus-crds` in `prometheus`)
   - [`system/cilium/helmrelease.yaml`](./system/cilium/helmrelease.yaml) (`cilium` in `kube-system`)
   - [`crds/flux-operator/helmrelease.yaml`](./crds/flux-operator/helmrelease.yaml) (`flux-operator` in `flux-system`)
   - [`system/fluxcd/helmrelease.yaml`](./system/fluxcd/helmrelease.yaml) (`flux` in `flux-system`)
1. **No `serviceMonitor` Override Needed**: Installing `prometheus-crds` first ensures the `ServiceMonitor` CRD exists before Cilium is installed, so Cilium deploys with its exact production values from [`system/cilium/helmrelease.yaml`](./system/cilium/helmrelease.yaml) on the first pass.
1. **Formatted by `nufmt`**: `nix fmt` already runs `nufmt` across `*.nu` files in the repo.

#### Core Helper Function (`bootstrap/bootstrap.nu`)

```nu
def apply_helmrelease [namespace: string, manifest: path] {
    let hr = open $manifest
    let name = $hr.metadata.name
    let chart = $hr.spec.chart.spec.url
    let version = $hr.spec.chart.spec.ref.tag
    let values = $hr.spec.values? | default {}

    print $"==> Installing HelmRelease ($namespace)/($name) \(($chart):($version)\)..."

    $values
    | to yaml
    | helm upgrade --install $name $chart
        --namespace $namespace
        --create-namespace
        --version $version
        --values -
        --reset-values
        --force-conflicts
        --wait
        --wait-for-jobs
}
```

______________________________________________________________________

## 3. Proposed Repository Layout & Workflow

### New Files to Add

```text
├── BOOTSTRAP.md                       # Documentation & runbook for cluster bootstrapping
├── bootstrap/
│   ├── default.nix                    # Nix flake module providing `bootstrap-cluster`
│   ├── bootstrap.nu                   # Interactive Nushell bootstrap script
│   └── secrets.yaml.tpl               # 1Password `op inject` template for flux-system secrets
```

### Interactive Bootstrap Script Flow (`bootstrap-cluster`)

Provided via `bootstrap/default.nix` so running `bootstrap-cluster` inside `nix develop` (or `nix run .#bootstrap-cluster`) executes an interactive, idempotent pipeline:

1. **Pre-flight Checks**:
   - Verify `KUBECONFIG` is reachable (`kubectl config current-context`, `kubectl get nodes`) — even if nodes report `NotReady` before Cilium CNI is installed.
   - Verify 1Password CLI authentication (`op whoami`).
   - Display target cluster context and nodes, then prompt for confirmation (`input "Proceed with bootstrap? [y/N]: "` unless `--yes` is passed).
1. **Namespaces & Secrets**:
   - Idempotently create `flux-system` and `prometheus` namespaces.
   - Inject bootstrap secrets from 1Password (`op inject -i bootstrap/secrets.yaml.tpl | kubectl apply --server-side -f -`).
1. **Core Chart Bootstrapping**:
   - `apply_helmrelease "prometheus" "crds/prometheus/helmrelease.yaml"`
   - `apply_helmrelease "kube-system" "system/cilium/helmrelease.yaml"`
   - Wait for all Kubernetes nodes to report `Ready` (`kubectl wait --for=condition=Ready nodes --all --timeout=120s`).
   - `apply_helmrelease "flux-system" "crds/flux-operator/helmrelease.yaml"`
   - `apply_helmrelease "flux-system" "system/fluxcd/helmrelease.yaml"`
1. **Post-Bootstrap Verification**:
   - Wait for `FluxInstance/flux` and `GitRepository/fluxcd-sync` to be created in `flux-system`.
   - Print status and instructions for watching reconciliation (`flux get kustomizations --watch`).

______________________________________________________________________

## 4. Implementation Steps

1. **Bootstrap Script & Secret Template (`bootstrap/`)**:
   - Create `bootstrap/secrets.yaml.tpl` referencing `op://Homelab/age.agekey/credential` and `op://Homelab/FluxCD Deploy Key/{private key?ssh-format=openssh,public key}`.
   - Create `bootstrap/bootstrap.nu` with pre-flight checks, interactive confirmation (`--yes` / `--dry-run` flags), `op inject`, and `apply_helmrelease` for `prometheus-crds`, `cilium`, `flux-operator`, and `flux`.
1. **Nix DevShell & Packaging (`bootstrap/default.nix`, `flake.nix`)**:
   - Package `bootstrap-cluster` using `writeNuBin` with runtime inputs `[_1password-cli kubectl kubernetes-helm fluxcd]`.
   - Import `./bootstrap` in `flake.nix`, expose `bootstrap-cluster` in `packages` and `devShellPackages`, and include `_1password-cli` in the devShell.
1. **Retire Ansible Bootstrap Roles**:
   - Remove `cilium` and `fluxcd` roles from `~/Documents/ansible-playbook/playbooks/k8s.yaml`, leaving only node & `kubeadm` provisioning in Ansible.
