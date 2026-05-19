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
