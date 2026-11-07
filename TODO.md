# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, security, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and roughly ordered by impact.

______________________________________________________________________

## 1. FluxCD Architecture & Reconciliation

The top-level Flux `Kustomization` resources (`crds.yaml`, `system.yaml`, `monitoring.yaml`, `backends.yaml`, `apps.yaml`) use a coarse dependency chain without explicit health checks or failure isolation.

- [ ] **Enable `wait: true` on Core Infrastructure Kustomizations**:
  - [ ] In `crds.yaml`, `system.yaml`, and `backends.yaml`, set `spec.wait: true` (and adjust `spec.timeout` as needed). Currently, `dependsOn` only waits for Flux to *apply* the manifests in `crds` and `system`, not for all CRDs, admission webhooks (`cert-manager`, `envoy-gateway`, `external-secrets`, `cnpg`), and `ClusterSecretStore`s to actually become `Ready`.
- [ ] **Decouple Sub-Kustomizations to Prevent Blast-Radius Blocking**:
  - [ ] Because `apps/kustomization.yaml` is a single monolithic Kustomize overlay applied by `apps.yaml`, a single syntax or SOPS error in a low-priority app (e.g., `super-sudoku` or `dao-2048`) blocks reconciliation for critical apps like `home-assistant` and `zigbee2mqtt`. Consider splitting `apps/` (and `backends/`) into per-app Flux `Kustomization` objects or grouping critical vs. non-critical workloads.
- [ ] **Standardize HelmRelease Drift Detection**:
  - [ ] `driftDetection.mode: enabled` is configured on 18 `HelmRelease`s (mostly `app-template` releases) but omitted on the remaining ~39 `HelmRelease`s. Standardize `driftDetection: { mode: enabled }` across all `HelmRelease` manifests (using `ignore` rules only where operators mutate their own resources).

______________________________________________________________________

## 2. Secrets Management Consolidation

The repository currently splits secrets across three patterns: SOPS-encrypted files committed to Git, `ExternalSecret`s backed by 1Password (`one-password-sdk`), and `ExternalSecret`s backed by an in-cluster `kubernetes` store (`rustfs-kubernetes-store`).

- [ ] **Migrate Remaining Static SOPS Secrets to 1Password (`ExternalSecret`)**:
  - [ ] Migrate app/backend SOPS secrets (`apps/media/vpn-secret.yaml`, `apps/media/nzbgeek-secret.yaml`, `apps/ws4kp/secrets/*`, `apps/zigbee2mqtt/secrets/*`, `apps/home-assistant/secrets/*`, `backends/ldap/lldap-secret.yaml`, `backends/authelia/*-secret.yaml`) to 1Password `ExternalSecret`s.
  - [ ] Keep SOPS strictly for the bootstrap secrets (`backends/one-password/secrets/*` and `system/fluxcd/webhook/secrets/*`) so only one secret backend is needed for day-to-day operations, and remove `spec.decryption` from Flux `Kustomization`s that no longer contain SOPS files.
- [ ] **Remove Unused `ClusterSecretStore`**:
  - [ ] Both `backends/one-password/cluster-secret-store.yaml` (`one-password` Connect server) and `backends/one-password/cluster-secret-store-sdk.yaml` (`one-password-sdk`) are deployed. If all `ExternalSecret`s use one store, decommission the redundant store.

______________________________________________________________________

## 3. Storage, Backups & Disaster Recovery

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which itself runs on a Longhorn PVC inside the same cluster. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in `monitoring/longhorn/recurringjob.yaml` (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Apps**:
  - [ ] Critical stateful configurations on Longhorn PVCs (`home-assistant` `/config`, `zigbee2mqtt`, `radarr`, `sonarr`, `prowlarr`, `qbittorrent`) rely solely on Longhorn volume replicas. Add either Longhorn scheduled volume backups or [VolSync](https://volsync.readthedocs.io/) replication to external storage.

______________________________________________________________________

## 4. Networking, Security & Policy

- [ ] **Enforce Pod Security Standards & Hardening**:
  - [ ] Only ~50% of `HelmRelease`s define `securityContext` or `resources`. Audit `apps/` and `backends/` (e.g., `home-assistant`, `ws4kp`, `httpbox`, `dao-2048`) to add `runAsNonRoot`, `readOnlyRootFilesystem`, dropped capabilities, and memory requests/limits (leveraging the already-deployed `goldilocks` / VPA recommendations).
- [ ] **Scope `tf-runner` RBAC in `backends/rustfs/terraform.yaml`**:
  - [ ] The `tf-runner` `Role` grants `verbs: ["*"]` on all `secrets` in the `rustfs` namespace. Scope write permissions (`update`, `patch`, `delete`) using `resourceNames` to only the state secret and output secrets managed by OpenTofu, and grant `get` on input secrets (`rustfs-root-secret`, `rustfs-users`).
