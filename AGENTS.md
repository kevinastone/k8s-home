# Agent Guidelines & Repository Knowledge

This file documents important architectural decisions, configurations, and caveats in the `k8s-home` repository. AI agents and developers should refer to this to maintain system stability and prevent regressions.

## Cluster Operations & Deployments

### GitOps-Only Operations (No Direct `kubectl apply`)

This cluster is managed entirely via GitOps. All infrastructure and application configurations are synchronized automatically from this repository.

- **Rule:** AI agents and developers must **never** run manual mutation or deployment commands directly against the cluster.
  - Do **not** run commands like `kubectl apply`, `kubectl delete`, `kubectl patch`, or `helm install`.
  - Do **not** manually create, edit, or delete namespace resources on the live cluster.
- **Workflow:** Any desired state changes must be declared by committing and pushing the configuration files to this Git repository. The GitOps controller will automatically synchronize and apply the changes.
- **Troubleshooting:** Read-only commands (e.g., `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl top`) are fully permitted for troubleshooting and inspection.

______________________________________________________________________

## Code Style & Formatting

### File Formatting (`nix fmt`)

This repository uses `treefmt` via Nix to enforce style consistency across files (including Markdown, YAML, and Nix).

- **Rule:** AI agents and developers must format all modified files using `nix fmt` in the repository root before staging or committing changes.
