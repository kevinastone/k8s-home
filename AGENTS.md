# Agent Guidelines & Repository Knowledge

This file documents important architectural decisions, configurations, and caveats in the `k8s-home` repository. AI agents and developers should refer to this to maintain system stability and prevent regressions.

## Cluster Operations & Deployments

### GitOps-Only Operations (No Direct `kubectl apply`)

This cluster is managed entirely via GitOps. All infrastructure and application configurations are synchronized automatically from this repository.

- **Rule:** AI agents and developers must **never** run manual mutation or deployment commands directly against the cluster.
  - Do **not** run commands like `kubectl apply`, `kubectl delete`, `kubectl patch`, or `helm install`.
  - Do **not** manually create, edit, or delete namespace resources on the live cluster.
- **Workflow:** Any desired state changes must be declared via configuration files in this Git repository. The GitOps controller will automatically synchronize and apply the changes once pushed.
- **Git Push Rule:** AI agents must **never** run `git push` without explicit user consent. Always verify and ask the user before pushing changes to remote.
- **Troubleshooting:** Read-only commands (e.g., `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl top`) are fully permitted for troubleshooting and inspection.

______________________________________________________________________

## Code Style & Formatting

### File Formatting (`nix fmt`)

This repository uses `treefmt` via Nix to enforce style consistency across files (including Markdown, YAML, and Nix).

- **Rule:** AI agents and developers must format all modified files using `nix fmt` in the repository root before staging or committing changes.

### Building Grafana Dashboards (`build-dashboards`)

Grafana dashboards modeled in CUE must be compiled to JSON whenever `.cue` files are modified:

```bash
nix develop --command build-dashboards <path-to-dashboards-dir>
```

### Running CUE Schema Tests Locally

To run unit tests and constraint validation for the Grafana CUE library:

```bash
nix develop --command cue vet -c ./lib/grafana/
```

### Running OPA Tests Locally

To run the OPA policy tests locally via the Nix development shell:

```bash
nix develop --command opa test apps/media/transcoder/policy/ -v
```

### Running Regal Lint Locally

To run the Regal linter locally via the Nix development shell:

```bash
nix develop --command regal lint apps/media/transcoder/policy
```

### Validating Renovate Configuration Locally

Whenever `.github/renovate.jsonc` is modified, validate it using the Nix development shell before committing:

```bash
nix develop --command renovate-config-validator .github/renovate.jsonc
```

### OPA / Rego Style Guidelines

- **Rule:** AI agents and developers must prefer string interpolation (`$""`) over `sprintf` for formatting strings in Rego policy files.
  - *Example:* Use `$"Unsupported target_codec: {target_codec}."` instead of `sprintf("Unsupported target_codec: %s.", [target_codec])`.
