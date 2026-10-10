# K8S at Home

Repo of Fluxcd kustomizations to deploy my homelab.

## Repository Structure

This repository follows a GitOps approach using [FluxCD](https://fluxcd.io/) to manage a Kubernetes cluster. The deployment flow is defined by the Flux `Kustomization` resources in the root of the repository, which apply configurations in a specific order:

- **`repos/`**: Helm repository definitions.
- **`crds/`**: Custom Resource Definitions required by various components.
- **`system/`**: Core infrastructure components (e.g., cert-manager, external-dns, storage drivers like Longhorn or Rook-Ceph).
- **`monitoring/`**: Observability stack (e.g., Prometheus, Grafana, Loki).
- **`backends/`**: Foundational services and databases (e.g., Postgres, LDAP, Authelia, DNS, MQTT).
- **`apps/`**: End-user applications and services (e.g., Home Assistant, media stack).

## Tools & Secrets

- **Secrets Management**: Handled via [SOPS](https://github.com/getsops/sops) with `age` encryption. Encrypted secrets are stored in the repo and decrypted seamlessly by Flux inside the cluster.
- **Development Environment**: Uses [Nix](https://nixos.org/) and `direnv` (`flake.nix`). Entering the directory automatically provisions a shell with all required tools like `kubectl`, `kustomize`, `sops`, `age`, and formatting tools (`treefmt`).

## Grafana Dashboards (CUE)

Dashboards across the repository (e.g., under `apps/` and `monitoring/`) are authored in **[CUE](https://cuelang.org/)** (`.cue` files) using shared definitions in `lib/grafana/`. This provides strongly-typed, reusable panel and layout components without hand-writing monolithic JSON files.

### Re-generating Dashboards

Whenever you update or add `.cue` dashboard templates, re-generate the JSON dashboards using any of the following methods:

1. **Via the Nix Development Shell** (with `nix develop` or direnv):

   ```bash
   # Build all dashboards in the repo
   build-dashboards .

   # Or build dashboards in a specific directory
   build-dashboards monitoring/victoria-metrics/dashboards
   ```

1. **Via Script Directly**:

   ```bash
   ./scripts/build_dashboards.sh monitoring/victoria-metrics/dashboards
   ```

1. **Or via `cue` directly**:

   ```bash
   cue export path/to/dashboard.cue -e out --out json > path/to/dashboard.json
   ```

### Running Schema & Layout Tests

To run unit tests and constraint validation for the Grafana CUE library:

```bash
# Via Nix development shell (or direnv)
cue vet -c ./lib/grafana/

# Or without active shell
nix develop --command cue vet -c ./lib/grafana/
```

Remember to format all modified files before committing:

```bash
nix fmt
```
