# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Off-Cluster Backups & Storage Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service and `kopiur` backs up key Longhorn PVCs to the NAS over SMB, several storage paths can be hardened further.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs`**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which runs as a 3-node distributed erasure-coded cluster on `openebs-rawfile`. Add an off-cluster replication job (e.g., `rclone` CronJob to the NAS SMB share or Backblaze B2) for `rustfs` buckets to satisfy the 3-2-1 backup rule.
- [ ] **Extend `components/kopiur` Backups to Remaining Stateful Media PVCs**:
  - [ ] Include [`components/kopiur`](./components/kopiur/kustomization.yaml) in [`media/kustomization.yaml`](./media/kustomization.yaml) and add the `kopiur.home-operations.com/backup: "true"` label to the `config` PVCs in [`media/qbittorrent/helmrelease.yaml`](./media/qbittorrent/helmrelease.yaml) (which holds `/config/qBittorrent/BT_backup` `.torrent` and `.fastresume` state) and [`media/sabnzbd/helmrelease.yaml`](./media/sabnzbd/helmrelease.yaml) (queue/history state).
- [ ] **Optimize VictoriaLogs Storage & High Availability**:
  - [ ] **Migrate VictoriaLogs from `vlsingle` (Longhorn) to Clustered / Replicated HA on `openebs-rawfile`**:
    - [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) currently runs `vlsingle` with a single `50Gi` replicated Longhorn PVC (`vlsingle-vm-stack`).
    - Because `openebs-rawfile` binds PVs to a single physical host (`nodeAffinity`), running a single instance on `openebs-rawfile` would cause VictoriaLogs to be unavailable whenever that node is drained or offline.
    - To combine local NVMe speed (`openebs-rawfile`) with resilience, migrate from `vlsingle` to **`vlcluster`** (using `vlinsert`, `vlselect`, and multi-node `vlstorage` on `openebs-rawfile`) or run **dual mirrored `vlsingle` instances** paired with dual-write in [`monitoring/vector/helmrelease-agent.yaml`](./monitoring/vector/helmrelease-agent.yaml) (`sinks.vlogs`) and `vmauth` failover, so log ingestion and search remain available across host restarts.

______________________________________________________________________

## 2. Kustomize Components, Templating & DRY Opportunities

- [ ] **Consolidate Media OpenTofu Modules (`prowlarr`, `radarr`, `sonarr`)**:
  - [ ] Currently 3 separate `Terraform` CRs in [`media/`](./media/) spawn 3 `tf-runner` pods every 10 minutes with duplicated `varsFrom` (`sabnzbd-secret`, `nzbgeek-secret`) and duplicated NZBGeek/SABnzbd resources across [`radarr/tofu/main.tf`](./media/radarr/tofu/main.tf) and [`sonarr/tofu/main.tf`](./media/sonarr/tofu/main.tf). Consolidate into a single `media/tofu/` module (or use `prowlarr_application_radarr` / `prowlarr_application_sonarr` to sync indexers from Prowlarr) to cut `tofu-controller` runner pods and state secrets from 3 to 1.

______________________________________________________________________

## 3. Secrets Management & FluxCD Lifecycle Architecture

- [ ] **Fix Cold-Bootstrap Dependency Inversion Between `system` `ExternalSecret`s and `backends/one-password`**:
  - [ ] [`backends.yaml`](./backends.yaml) depends on [`system.yaml`](./system.yaml) (`dependsOn: [system]`), yet 5 directories in `system/` (`cert-manager`, `external-dns`, `csi-driver-smb`, `kopiur`, `tailscale-operator`) create `ExternalSecret`s targeting `ClusterSecretStore/one-password`, which is deployed later in [`backends/one-password/`](./backends/one-password/kustomization.yaml).
  - [ ] Move `one-password` into `system/one-password/` (or a dedicated stage between `crds` and `system`) so `ClusterSecretStore/one-password` is ready before `system` workloads reconcile, and deduplicate the byte-for-byte identical [`system/cert-manager/cloudflare-api-token-secret.yaml`](./system/cert-manager/cloudflare-api-token-secret.yaml) and [`system/external-dns/cloudflare-api-token-secret.yaml`](./system/external-dns/cloudflare-api-token-secret.yaml).
- [ ] **Unify `cert-manager` & `envoy-gateway` CRD Management with Other Operators**:
  - [ ] Unlike all other operators in `crds/`, [`crds/cert-manager/crds.yaml`](./crds/cert-manager/crds.yaml) and [`crds/envoy-gateway/crds.yaml`](./crds/envoy-gateway/crds.yaml) clone full upstream Git repositories via `GitRepository` + nested Flux `Kustomization`s while their `HelmRelease`s run in `system/` with `crds: Skip`, requiring custom `groupName` rules in [`.github/renovate.jsonc`](./.github/renovate.jsonc) to prevent version skew.
  - [ ] Move the `cert-manager` and `envoy-gateway` controller `HelmRelease`s into `crds/` with `crds: CreateReplace` (leaving `ClusterIssuer`, `GatewayClass`, and `Gateway` CRs in `system/`) to eliminate 2 `GitRepository` clones, 2 extra Flux `Kustomization`s, and 24 lines of Renovate grouping rules.
- [ ] **Custom `kube-rs` Operator for Per-App ClickHouse Users**:
  - [ ] **Goal:** Replace centralized `users.d` provisioning in [`backends/clickhouse/users.yaml`](./backends/clickhouse/users.yaml) with self-service per-app `ClickHouseUser` CRs while keeping admin credentials strictly inside the `clickhouse` namespace (avoiding the root-secret fan-out trade-off of per-namespace `tf-runner` components).
  - [ ] **CRD & Controller (`kube-rs`)**:
    - Define a `ClickHouseUser` CRD via `#[derive(CustomResource, JsonSchema)]` (`spec.username`, `spec.profile`, `spec.grants`, `spec.secretName`, and `status.conditions` / password hash fingerprint).
    - Run a single static Rust binary (`kube`, `k8s-openapi`, `tokio`, `reqwest` with `rustls-tls`) in the `clickhouse` namespace using `clickhouse-admin-user` credentials against `http://clickhouse.clickhouse.svc.cluster.local:8123`.
    - Reconcile with `kube::runtime::finalizer`: generate a password `Secret` in the CR's namespace (owned via `OwnerReference`), execute `CREATE USER IF NOT EXISTS ... IDENTIFIED WITH bcrypt_password BY ... COMMENT 'k8s:<namespace>/<name>'` (checking ownership to prevent cross-namespace username collisions), reconcile `GRANT`/`REVOKE` against `SHOW GRANTS`, and `DROP USER IF EXISTS` on delete.
    - Requeue periodically (e.g., every 10m) so users and grants self-heal automatically after a `/data` PVC wipe.
  - [ ] **Packaging & Migration**:
    - Publish a minimal `scratch`/`distroless` container image and chart/manifests, installing the CRD in `crds/` and the operator in `backends/clickhouse/`.
    - Migrate `grafana` and `vector` to `ClickHouseUser` CRs with least-privilege grants (`SELECT` / `INSERT` on `metrics.*`), then remove `clickhouse-grafana-user`, `clickhouse-vector-user`, [`backends/clickhouse/vector-creds.yaml`](./backends/clickhouse/vector-creds.yaml), and [`backends/clickhouse/kubernetes-store.yaml`](./backends/clickhouse/kubernetes-store.yaml).
    - *(Optional follow-up)* Evaluate applying the same operator pattern to `RustFSBucket` to remove `rustfs-root-secret` fan-out in [`components/rustfs-bucket/`](./components/rustfs-bucket/kustomization.yaml).

______________________________________________________________________

## 4. Repository Organization & Directory Boundaries

- [ ] **Standardize Service vs. `monitoring/` Directory Boundaries**:
  - [ ] **Co-locate Service Dashboards, Alerts & Maintenance Jobs**: Currently, some services co-locate their `dashboards/` and `prometheus-rule.yaml` inside their own directory (`system/cert-manager/`, `system/longhorn/`, `backends/rustfs/`, `backends/authelia/`), while others split them into `monitoring/<service>/` (`monitoring/argo/`, `monitoring/dragonfly/`, `monitoring/envoy-gateway/`, `monitoring/external-secrets/`, `monitoring/openebs/`, `monitoring/tofu-controller/`). Because `PrometheusRule` and `PodMonitor` CRDs are already reconciled in the `crds` stage prior to `system`, `backends`, and `apps`, co-locating `dashboards/`, `pod-monitor.yaml`, and `prometheus-rule.yaml` directly within each service's directory simplifies navigation and keeps `monitoring/` focused strictly on the observability stack (`victoria-metrics`, `grafana`, `vector`, `prometheus`, `goldilocks`).
  - [ ] **Move Longhorn `RecurringJob`s out of `monitoring/longhorn/`**: [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) defines storage maintenance jobs (`snapshot-cleanup`, `filesystem-trim`) inside `monitoring/` rather than [`system/longhorn/`](./system/longhorn/kustomization.yaml). Move `recurringjob.yaml` into `system/longhorn/` (decoupling Longhorn CRD installation if needed) and remove `monitoring/longhorn/`.
  - [ ] **Align `apps/home-monitoring/` and `monitoring/{network-ups-tools,peanut}`**: [`apps/home-monitoring/`](./apps/home-monitoring/kustomization.yaml) lives under `apps/` despite only containing a `Namespace` and a Grafana dashboard (`dashboards/home.cue`), whereas [`monitoring/network-ups-tools/`](./monitoring/network-ups-tools/kustomization.yaml) and [`monitoring/peanut/`](./monitoring/peanut/kustomization.yaml) deploy UPS daemon/web workloads under `monitoring/`. Standardize where hardware monitoring workloads and standalone dashboards reside.

______________________________________________________________________

## 5. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.
