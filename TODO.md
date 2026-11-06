# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, security, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and roughly ordered by impact.

______________________________________________________________________

## 1. CI/CD, Validation & Developer Experience

Currently, `.github/workflows/ci.yaml` only runs `nix flake check` (which executes `treefmt`). While formatting is enforced, broken Kustomizations, invalid CUE schemas, or Rego policy regressions are not caught in CI.

- [x] **Expand Nix Flake Checks (`flake.nix`)**:
  - [x] Add `cue vet -c ./lib/grafana/` to `checks` in `flake.nix` so Grafana dashboard schema tests run automatically on every PR.
  - [x] Add `opa test apps/media/transcoder/policy/ -v` and `regal lint apps/media/transcoder/policy` to `checks` in `flake.nix`.
  - [x] Add `renovate-config-validator .github/renovate.jsonc` to `checks` in `flake.nix`.
  - [x] Add a check verifying that compiled dashboard `.json` files are in sync with their `.cue` sources (`build-dashboards`).
- [x] **Add Kubernetes & Flux Manifest Validation in CI**:
  - [x] Integrated `home-operations/flate` into GitHub Actions (`.github/workflows/ci.yaml`) with `flate test all` for manifest validation and `flate diff` on pull requests for rendered diffs in job summaries.
- [x] **Pin Digest for CNPG PostgreSQL Images in Renovate (`.github/renovate.jsonc`)**:
  - [x] CloudNativePG `Cluster` manifests (`spec.imageName: ghcr.io/cloudnative-pg/postgresql:17.5-10`) now tracked via a custom Renovate regex manager with automatic digest pinning.

______________________________________________________________________

## 2. FluxCD Architecture & Reconciliation

The top-level Flux `Kustomization` resources (`crds.yaml`, `system.yaml`, `monitoring.yaml`, `backends.yaml`, `apps.yaml`) use a coarse dependency chain without explicit health checks or failure isolation.

- [ ] **Enable `wait: true` on Core Infrastructure Kustomizations**:
  - [ ] In `crds.yaml`, `system.yaml`, and `backends.yaml`, set `spec.wait: true` (and adjust `spec.timeout` as needed). Currently, `dependsOn` only waits for Flux to *apply* the manifests in `crds` and `system`, not for all CRDs, admission webhooks (`cert-manager`, `envoy-gateway`, `external-secrets`, `cnpg`), and `ClusterSecretStore`s to actually become `Ready`.
- [ ] **Decouple Sub-Kustomizations to Prevent Blast-Radius Blocking**:
  - [ ] Because `apps/kustomization.yaml` is a single monolithic Kustomize overlay applied by `apps.yaml`, a single syntax or SOPS error in a low-priority app (e.g., `super-sudoku` or `dao-2048`) blocks reconciliation for critical apps like `home-assistant` and `zigbee2mqtt`. Consider splitting `apps/` (and `backends/`) into per-app Flux `Kustomization` objects or grouping critical vs. non-critical workloads.
- [ ] **Standardize HelmRelease Drift Detection**:
  - [ ] `driftDetection.mode: enabled` is configured on 18 `HelmRelease`s (mostly `app-template` releases) but omitted on the remaining ~39 `HelmRelease`s. Standardize `driftDetection: { mode: enabled }` across all `HelmRelease` manifests (using `ignore` rules only where operators mutate their own resources).
- [x] **Complete OCI Repository Migration**:
  - [x] Migrated all eligible charts to inline `OCIRepository` definitions, migrated logging to VictoriaLogs + Vector, and removed `repos/helm/grafana.yaml`. Remaining charts in `repos/helm/` (`external-dns`, `metrics-server`, `descheduler`, `fairwinds`, `longhorn`, `tailscale`, `eraser`, `csi-driver-smb`, `dao-2048`) do not currently have official upstream OCI equivalents.
- [x] **Clean Up Ephemeral Annotations in Git**:
  - [x] Removed imperative `reconcile.fluxcd.io/requestedAt` annotations from `backends/authelia/helmrelease.yaml`, `apps/media/sabnzbd/helmrelease.yaml`, and `apps/media/radarr/helmrelease.yaml`.

______________________________________________________________________

## 3. Secrets Management Consolidation

The repository currently splits secrets across three patterns: SOPS-encrypted files committed to Git, `ExternalSecret`s backed by 1Password (`one-password-sdk`), and `ExternalSecret`s backed by an in-cluster `kubernetes` store (`rustfs-kubernetes-store`).

- [ ] **Migrate Remaining Static SOPS Secrets to 1Password (`ExternalSecret`)**:
  - [x] Consolidate `system/cert-manager/cloudflare-api-token-secret.yaml` and `system/external-dns/cloudflare-api-token-secret.yaml` to fetch from a single 1Password item (`"Cloudflare DNS API Token"`).
  - [ ] Migrate app/backend SOPS secrets (`apps/media/vpn-secret.yaml`, `apps/media/nzbgeek-secret.yaml`, `apps/ws4kp/secrets/*`, `apps/zigbee2mqtt/secrets/*`, `apps/home-assistant/secrets/*`, `backends/ldap/lldap-secret.yaml`, `backends/authelia/*-secret.yaml`) to 1Password `ExternalSecret`s.
  - [ ] Keep SOPS strictly for the bootstrap secrets (`backends/one-password/secrets/*` and `system/fluxcd/webhook/secrets/*`) so only one secret backend is needed for day-to-day operations, and remove `spec.decryption` from Flux `Kustomization`s that no longer contain SOPS files.
- [ ] **Remove Unused `ClusterSecretStore`**:
  - [ ] Both `backends/one-password/cluster-secret-store.yaml` (`one-password` Connect server) and `backends/one-password/cluster-secret-store-sdk.yaml` (`one-password-sdk`) are deployed. If all `ExternalSecret`s use one store, decommission the redundant store.

______________________________________________________________________

## 4. Storage, Backups & Disaster Recovery

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which itself runs on a Longhorn PVC inside the same cluster. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in `monitoring/longhorn/recurringjob.yaml` (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Apps**:
  - [ ] Critical stateful configurations on Longhorn PVCs (`home-assistant` `/config`, `zigbee2mqtt`, `radarr`, `sonarr`, `prowlarr`, `qbittorrent`) rely solely on Longhorn volume replicas. Add either Longhorn scheduled volume backups or [VolSync](https://volsync.readthedocs.io/) replication to external storage.
- [x] **Fix `home-assistant` PVC Access Mode**:
  - [x] Switched `persistence.config.accessMode` from `ReadWriteMany` to `ReadWriteOnce` in `apps/home-assistant/helmrelease.yaml`. With `controllers.main.type: statefulset` (single replica), `ReadWriteOnce` eliminates the Longhorn `share-manager` NFSv4 pod overhead and prevents SQLite file-locking issues.
- [x] **Standardize CNPG Restore Runbooks / Templates**:
  - [x] Removed ad-hoc test manifest `apps/home-assistant/postgres/cluster3.yaml` and created standardized disaster recovery / PITR runbook and recovery template in `components/postgres/`.

______________________________________________________________________

## 5. Networking, Security & Policy

- [x] **Tighten CORS on Envoy Gateway `SecurityPolicy` (`backends/envoy-gateway/security-policy.yaml`)**:
  - [x] Restricted `allowOrigins` from `*` to `["https://*.k8s.kevinastone.com"]` on `auth-gateway-policy` and `public-gateway-policy`.
- [x] **Consolidate MetalLB vs. Cilium BGP**:
  - [x] Phase 1: Draft native Cilium BGP Control Plane and LB IPAM manifests (`system/cilium/bgp/`).
  - [x] Phase 2: Cut over active traffic from MetalLB to Cilium BGP (wired `system/cilium/bgp` into `system/cilium/kustomization.yaml`, decommissioned MetalLB, cleaned up deprecated annotations).
- [ ] **Enforce Pod Security Standards & Hardening**:
  - [ ] Only ~50% of `HelmRelease`s define `securityContext` or `resources`. Audit `apps/` and `backends/` (e.g., `home-assistant`, `ws4kp`, `httpbox`, `dao-2048`) to add `runAsNonRoot`, `readOnlyRootFilesystem`, dropped capabilities, and memory requests/limits (leveraging the already-deployed `goldilocks` / VPA recommendations).
- [ ] **Scope `tf-runner` RBAC in `backends/rustfs/terraform.yaml`**:
  - [ ] The `tf-runner` `Role` grants `verbs: ["*"]` on all `secrets` in the `rustfs` namespace. Scope write permissions (`update`, `patch`, `delete`) using `resourceNames` to only the state secret and output secrets managed by OpenTofu, and grant `get` on input secrets (`rustfs-root-secret`, `rustfs-users`).

______________________________________________________________________

## 6. Observability & Alerting

- [x] **Add Alerting Rules for Critical Homelab Failure Modes**:
  - [x] While VictoriaMetrics (`vmalert` + `alertmanager`) and `karma` are deployed, custom alerting rules are sparse (mostly Flux, cert-manager, and Longhorn). Add `VMRule` / `PrometheusRule` definitions for:
    - [x] **UPS / Power events**: Alert on `network_ups_tools` battery state (`OB` / On Battery) or low battery charge (`monitoring/network-ups-tools/prometheus-rule.yaml`).
    - [x] **CloudNativePG**: Alert on failed `ScheduledBackup`s, replication lag, or WAL archiving failures (`monitoring/postgres/prometheus-rule.yaml`).
    - [x] **External Secrets**: Alert when any `ExternalSecret` or `ClusterSecretStore` is `Ready=False` (`monitoring/external-secrets/prometheus-rule.yaml`).
    - [x] **OpenTofu (`tofu-controller`)**: Alert on `Terraform` resource reconciliation or plan/apply failures (`monitoring/tofu-controller/prometheus-rule.yaml`).

______________________________________________________________________

## 7. Repository Hygiene & Dead Code Cleanup

Several directories and manifests exist on disk but are commented out or unreferenced by any `kustomization.yaml`. Either remove them (relying on Git history if needed later) or document their status:

- [ ] **Remove or Archive Unreferenced Directories**:
  - [x] Removed `backends/airflow/` and `repos/helm/airflow.yaml` (and unlinked from `repos/helm/kustomization.yaml`).
  - [ ] `system/rook-cluster/` and `crds/rook-operator/` — Commented out in `crds/kustomization.yaml` and unreferenced in `system/kustomization.yaml`.
  - [ ] `system/intel-gpu-plugin/` — Commented out in `system/kustomization.yaml`.
  - [ ] `apps/media/transmission/` — Commented out in `apps/media/kustomization.yaml` (superseded by `qbittorrent`).
  - [ ] `monitoring/synology/` — Commented out in `monitoring/kustomization.yaml`.
  - [x] `apps/home-assistant/postgres/cluster3.yaml` — Removed ad-hoc recovery test manifest and unlinked from `apps/home-assistant/postgres/kustomization.yaml`.
  - [x] `repos/git/kustomization.yaml` — Removed empty `repos/git/` directory and unlinked from `repos/kustomization.yaml`.
- [x] **Update `README.md` to Reflect Current Architecture**:
  - [x] Updated `README.md` to reflect current architecture: Cilium native BGP & LB IPAM, Envoy Gateway, External Secrets + 1Password, VictoriaMetrics, CloudNativePG, OpenTofu (`tofu-controller`), and developer workflows.
