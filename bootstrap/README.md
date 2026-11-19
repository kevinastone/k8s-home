# Cluster Bootstrap

Interactive Nushell bootstrapper (`bootstrap-cluster`) for bringing a bare `kubeadm` cluster to the point where FluxCD can reconcile this repository.

## Scope & Boundary with Ansible

**Provisioned by Ansible:**

- Node OS prerequisites (`swap_off`, `cluster_ip` / HAProxy + Keepalived, kernel modules, sysctls, apt packages).
- `kubeadm init` (`roles/kubernetes`), control-plane untainting, and worker label assignment.
- Providing a working `KUBECONFIG` targeting the cluster API server.

**Handled by `bootstrap-cluster` (`bootstrap/bootstrap.nu`):**

1. **Pre-flight checks**: Verifies `HelmRelease` manifests, `kubectl` cluster connectivity, and `op` (1Password CLI) authentication.
1. **Namespaces**: Idempotently creates `flux-system` and `prometheus`.
1. **Bootstrap secrets**: Reads secrets from 1Password via `op read` and applies them with `kubectl apply --server-side`:
   - `sops-age` (`flux-system`): `op://Homelab/age.agekey/credential` (used by Flux to decrypt SOPS-encrypted secrets).
   - `fluxcd-sync` (`flux-system`): `op://Homelab/FluxCD Deploy Key/{private key?ssh-format=openssh,public key}` + GitHub `known_hosts` (read-only SSH deploy key for `ssh://git@github.com/kevinastone/k8s-home`).
1. **Core HelmReleases**: Reads `.metadata.name`, `.spec.chart.spec.url`, `.spec.chart.spec.ref.tag`, and `.spec.values` directly from the Flux `HelmRelease` manifests (zero duplication) and installs them in order:
   - [`../crds/prometheus/helmrelease.yaml`](../crds/prometheus/helmrelease.yaml) (`prometheus-crds` in `prometheus` — installed first so `ServiceMonitor` CRDs exist before Cilium)
   - [`../system/cilium/helmrelease.yaml`](../system/cilium/helmrelease.yaml) (`cilium` in `kube-system`), then waits for all nodes to report `Ready`
   - [`../crds/flux-operator/helmrelease.yaml`](../crds/flux-operator/helmrelease.yaml) (`flux-operator` in `flux-system`)
   - [`../system/fluxcd/helmrelease.yaml`](../system/fluxcd/helmrelease.yaml) (`flux` in `flux-system`)
1. **Verification**: Waits for `gitrepository/fluxcd-sync` in `flux-system` and prints `flux get kustomizations`.

## Prerequisites

- Working `KUBECONFIG` targeting the bare cluster.
- 1Password CLI (`op`) installed on `PATH` (e.g. `brew install 1password-cli` on macOS so Desktop App Touch ID integration works).
- Nix / `direnv` (`nix develop` or `nix run .#bootstrap-cluster`).

## Usage

```bash
# Preview and validate HelmReleases without modifying the cluster
bootstrap-cluster --dry-run

# Run interactive bootstrap
bootstrap-cluster

# Non-interactive bootstrap
bootstrap-cluster --yes

# Or run directly via Nix without entering the devShell
nix run .#bootstrap-cluster -- --dry-run
```

## Watch Reconciliation

```bash
flux get kustomizations --watch
```
