# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Off-Cluster Backups & Storage Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure without off-cluster copies.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which now runs as a 3-node distributed erasure-coded cluster on `openebs-rawfile`. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets to satisfy the 3-2-1 backup rule.
  - [ ] Provision a `longhorn` bucket in [`backends/rustfs/tofu/main.tf`](./backends/rustfs/tofu/main.tf), configure Longhorn's `backupTarget` (`s3://longhorn@us-east-1/` pointing to `rustfs` or an off-cluster target) in [`system/longhorn/helmrelease.yaml`](./system/longhorn/helmrelease.yaml), and add a `RecurringJob` with `task: backup` in [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Workloads**:
  - [ ] While `radarr`, `sonarr`, and `prowlarr` store their state in CNPG PostgreSQL + OpenTofu/Recyclarr, critical non-Postgres Longhorn PVCs still rely solely on in-cluster Longhorn volume replicas:
    - [`apps/home-assistant/helmrelease.yaml`](./apps/home-assistant/helmrelease.yaml) (`/config` PVC — `.storage/` integrations and custom components; can also use Home Assistant's native S3 backup integration targeting `rustfs`)
    - [`apps/zigbee2mqtt/helmrelease.yaml`](./apps/zigbee2mqtt/helmrelease.yaml) (`/data` PVC — `database.db` device pairings and `coordinator_backup.json`)
    - [`monitoring/victoria-metrics/vmcluster-influx.yaml`](./monitoring/victoria-metrics/vmcluster-influx.yaml) (`60Gi` PVC — 365-day retention of home-monitoring sensor metrics; can also use `vmbackup` to `s3://victoria-metrics` on `rustfs`)
  - [ ] Add Longhorn scheduled backups to `rustfs` (or [VolSync](https://volsync.readthedocs.io/) replication) for these PVCs.
- [ ] **Optimize VictoriaLogs Storage & High Availability**:
  - [ ] **Migrate VictoriaLogs from `vlsingle` (Longhorn) to Clustered / Replicated HA on `openebs-rawfile`**:
    - [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) currently runs `vlsingle` with a single `50Gi` replicated Longhorn PVC (`vlsingle-vm-stack`).
    - Because `openebs-rawfile` binds PVs to a single physical host (`nodeAffinity`), running a single instance on `openebs-rawfile` would cause VictoriaLogs to be unavailable whenever that node is drained or offline.
    - To combine local NVMe speed (`openebs-rawfile`) with resilience, migrate from `vlsingle` to **`vlcluster`** (using `vlinsert`, `vlselect`, and multi-node `vlstorage` on `openebs-rawfile`) or run **dual mirrored `vlsingle` instances** paired with dual-write in [`monitoring/vector/helmrelease-agent.yaml`](./monitoring/vector/helmrelease-agent.yaml) (`sinks.vlogs`) and `vmauth` failover, so log ingestion and search remain available across host restarts.

______________________________________________________________________

## 2. Repository Organization & Kustomize Architecture

- [x] **Extract Duplicated Manifests into Reusable Kustomize `components/`**:
  - [x] **`components/tf-runner` (OpenTofu RBAC)**: The 28-line `tf-runner` RBAC block (`ServiceAccount`, `Role`, `RoleBinding`) is duplicated across [`backends/rustfs/terraform.yaml`](./backends/rustfs/terraform.yaml), [`backends/ldap/terraform.yaml`](./backends/ldap/terraform.yaml), and the bottom of [`apps/media/sonarr/terraform.yaml`](./apps/media/sonarr/terraform.yaml) (making `prowlarr` and `radarr` implicitly depend on `sonarr`'s manifest for their shared runner `ServiceAccount` in the `media` namespace). Extract `tf-runner` into `components/tf-runner/` and include it at the namespace level (`apps/media/kustomization.yaml`, `backends/rustfs/kustomization.yaml`, `backends/ldap/kustomization.yaml`).
  - [x] **`components/kustomizeconfig` (Consolidate 17 Boilerplate `kustomizeconfig.yaml` Files)**: 17 directories across `apps/`, `backends/`, `monitoring/`, and `system/` maintain nearly identical `kustomizeconfig.yaml` files to configure `nameReference` for `HelmRelease` persistence mounts. Replace them with a single shared `kustomizeconfig.yaml` using wildcard fieldSpecs (`spec/values/persistence/*/name`) or a shared Kustomize component.
  - [x] **Expand `components/postgres` with Base CNPG Templates**: [`components/postgres/`](./components/postgres/kustomization.yaml) currently only contains `s3-creds.yaml`, while all 5 PostgreSQL directories (`apps/media/postgres`, `apps/home-assistant/postgres`, `backends/authelia/postgres`, `backends/ldap/postgres`, `backends/mqtt/pgmqtt/postgres`) duplicate ~90% identical `cluster.yaml`, `backup.yaml`, and `objectstore.yaml` manifests (leading to drift such as missing `walStorage` in [`backends/ldap/postgres/cluster.yaml`](./backends/ldap/postgres/cluster.yaml) and `cluster2.yaml`/`backup2.yaml` naming in [`apps/home-assistant/postgres/`](./apps/home-assistant/postgres/kustomization.yaml)). Move base `Cluster`, `ScheduledBackup`, and `ObjectStore` definitions into `components/postgres/` and apply per-app Kustomize patches for database names, S3 paths, and storage sizes.
- [ ] **Standardize Service vs. `monitoring/` Directory Boundaries**:
  - [ ] **Co-locate Service Dashboards, Alerts & Maintenance Jobs**: Currently, some services co-locate their `dashboards/` and `prometheus-rule.yaml` inside their own directory (`system/cert-manager/`, `system/longhorn/`, `backends/rustfs/`, `backends/authelia/`), while others split them into `monitoring/<service>/` (`monitoring/argo/`, `monitoring/dragonfly/`, `monitoring/envoy-gateway/`, `monitoring/external-secrets/`, `monitoring/openebs/`, `monitoring/tofu-controller/`). Because `PrometheusRule` and `PodMonitor` CRDs are already reconciled in the `crds` stage prior to `system`, `backends`, and `apps`, co-locating `dashboards/`, `pod-monitor.yaml`, and `prometheus-rule.yaml` directly within each service's directory simplifies navigation and keeps `monitoring/` focused strictly on the observability stack (`victoria-metrics`, `grafana`, `vector`, `prometheus`, `goldilocks`).
  - [ ] **Move Longhorn `RecurringJob`s out of `monitoring/longhorn/`**: [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) defines storage maintenance jobs (`snapshot-cleanup`, `filesystem-trim`) inside `monitoring/` rather than [`system/longhorn/`](./system/longhorn/kustomization.yaml). Move `recurringjob.yaml` into `system/longhorn/` (decoupling Longhorn CRD installation if needed) and remove `monitoring/longhorn/`.
  - [ ] **Align `apps/home-monitoring/` and `monitoring/{network-ups-tools,peanut}`**: [`apps/home-monitoring/`](./apps/home-monitoring/kustomization.yaml) lives under `apps/` despite only containing a `Namespace` and a Grafana dashboard (`dashboards/home.cue`), whereas [`monitoring/network-ups-tools/`](./monitoring/network-ups-tools/kustomization.yaml) and [`monitoring/peanut/`](./monitoring/peanut/kustomization.yaml) deploy UPS daemon/web workloads under `monitoring/`. Standardize where hardware monitoring workloads and standalone dashboards reside.
- [x] **Consolidate Single-Use `HelmRepository` Sources in `repos/helm/`**:
  - [x] Following the migration to inline `spec.chart.kind: OCIRepository` in most `HelmRelease` manifests, [`repos/helm/`](./repos/helm/kustomization.yaml) still holds 8 single-consumer `HelmRepository` definitions. Migrate charts that publish official OCI artifacts (`descheduler`, `external-dns`, `metrics-server`, `tailscale`) to inline `OCIRepository` specs, or co-locate single-consumer `HelmRepository` resources with their `HelmRelease`, keeping only shared repositories (`bjw-s-labs.yaml`, `fairwinds.yaml`) in `repos/helm/`.

______________________________________________________________________

## 3. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.

______________________________________________________________________

## 4. Observability & Telemetry Architecture

- [ ] **Migrate InfluxDB Line-Protocol & OTLP Ingestion from VMAgent to Vector Aggregator**:
  - [x] **Deploy Dedicated `vector-aggregator` Workload**:
    - The current `vector` deployment in [`monitoring/vector/helmrelease-agent.yaml`](./monitoring/vector/helmrelease-agent.yaml) runs as a `role: Agent` DaemonSet solely for node-local container log collection (`kubernetes_logs`).
    - Deployed a separate `vector-aggregator` `HelmRelease` in [`monitoring/vector/helmrelease-aggregator.yaml`](./monitoring/vector/helmrelease-aggregator.yaml) configured as `role: Stateless-Aggregator` (Deployment with 2 replicas, anti-affinity, and ClusterIP Service), isolating inbound metric ingestion from node log collection.
  - [x] **Ingestion Pipeline & Storage Routing**:
    - Configured raw InfluxDB HTTP source (`port 8086`) and OpenTelemetry source (`ports 4317/4318`) to receive writes from Home Assistant and Telegraf.
    - Applied VRL transforms to normalize string fields, map `db` tags, and prefix `.name = $db_$name` before storage.
    - Configured `prometheus_remote_write` sink with end-to-end acknowledgements to [`monitoring/victoria-metrics/vmcluster-influx.yaml`](./monitoring/victoria-metrics/vmcluster-influx.yaml).
    - Deployed `vector-gateway` and routes in [`monitoring/vector/`](./monitoring/vector/) for `influxdb.k8s.kevinastone.com` and `otlp.k8s.kevinastone.com`.
  - [ ] **Clean Up Obsolete VMAgent Relabeling & Remote-Write**:
    - Remove the deprecated `inlineRelabelConfig` block (`retention="influx-365d"`, `$db_$name`, `labeldrop db`) and the secondary `vminsert-vmcluster-influx` remoteWrite target from [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) now that Vector handles ingestion directly.
  - [ ] **Modular Configuration Architecture for Scale**:
    - Avoid monolithic inline `customConfig` blocks in Helm values by leveraging Vector's multi-file configuration merging (`--config-dir`).
    - Split configuration into domain-specific files (`sources/`, `transforms/`, `sinks/`) and externalize `.vrl` transform scripts into dedicated files (`file!/etc/vector/vrl/...`).
    - Package configuration and VRL scripts into Kubernetes ConfigMaps using Kustomize `configMapGenerator` and mount them via `existingConfigMaps`, ensuring automatic rolling pod restarts upon configuration changes via content-hashed ConfigMap names.
