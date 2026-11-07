# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Observability, Alerting & Dashboards

Several alerting rules and dashboards have subtle metric or datasource mismatches following recent migrations (Flux v2.1+ metric changes, Loki to VictoriaLogs, and Synology SNMP removal).

- [ ] **Fix Broken `FluxReconciliationFailure` and `TerraformReconciliationFailed` Alert Queries**:
  - [ ] [`monitoring/fluxcd/prometheus-rule.yaml`](./monitoring/fluxcd/prometheus-rule.yaml) and [`monitoring/tofu-controller/prometheus-rule.yaml`](./monitoring/tofu-controller/prometheus-rule.yaml) query `gotk_reconcile_condition`, a metric that was **removed in Flux v2.1+**. As a result, `FluxReconciliationFailure` currently evaluates to an empty vector and **never fires** when a `Kustomization` or `HelmRelease` fails.
  - [ ] Update `FluxReconciliationFailure` in [`monitoring/fluxcd/prometheus-rule.yaml`](./monitoring/fluxcd/prometheus-rule.yaml) to query `gotk_resource_info{ready="False"} == 1` (emitted by the `kube-state-metrics` `customResourceState` config in [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) and already used by `fluxcd-cluster.json`).
  - [ ] Add `infra.contrib.fluxcd.io/v1alpha2` (`Terraform`) to `customResourceState` in [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) and update `TerraformReconciliationFailed` to query `gotk_resource_info{customresource_kind="Terraform", ready="False"} == 1`.
- [ ] **Fix `UPSOffline` Alert Logic in [`monitoring/network-ups-tools/prometheus-rule.yaml`](./monitoring/network-ups-tools/prometheus-rule.yaml)**:
  - [ ] `UPSOffline` currently triggers on `network_ups_tools_ups_status{flag="OL"} == 0`. Whenever utility power fails and the UPS switches to battery (`OB`), `flag="OL"` becomes `0`, causing `UPSOffline` to fire redundantly alongside `UPSOnBattery`. Conversely, if the NUT exporter loses connection to the UPS, the metric disappears entirely. Update `UPSOffline` to check `absent(network_ups_tools_ups_status{flag="OL"})` or `up{job=~".*network-ups-tools.*"} == 0`.
- [ ] **Add Longhorn Volume Health & Storage Capacity Alerts ([`system/longhorn/prometheus-rule.yaml`](./system/longhorn/prometheus-rule.yaml))**:
  - [ ] Currently [`system/longhorn/prometheus-rule.yaml`](./system/longhorn/prometheus-rule.yaml) only alerts on `LonghornExcessInstanceManagers`. Add alerts for degraded/faulted volumes (`longhorn_volume_robustness == 2` or `== 3`), volume capacity exhaustion (`(longhorn_volume_actual_size_bytes / longhorn_volume_capacity_bytes) > 0.85`), and node disk pressure (`(longhorn_node_storage_usage_bytes / longhorn_node_storage_capacity_bytes) > 0.85`).
- [ ] **Migrate or Remove Broken Loki Dashboard ([`monitoring/fluxcd/dashboards/`](./monitoring/fluxcd/dashboards/))**:
  - [ ] [`monitoring/fluxcd/kustomization.yaml`](./monitoring/fluxcd/kustomization.yaml) deploys `dashboards/fluxcd-logs.json`, which queries `datasource: "loki"` (`DS_LOKI`). Since logging was migrated from Loki/Alloy to VictoriaLogs + Vector, this dashboard is broken in Grafana. Additionally, `monitoring/fluxcd/dashboards/logs.json` is an unreferenced duplicate file on disk. Either replace `fluxcd-logs.json` with a VictoriaLogs dashboard or remove `fluxcd-logs.json` and `logs.json`.
- [ ] **Decommission Idle `snmp-exporter` ([`monitoring/prometheus/helmrelease-snmp-exporter.yaml`](./monitoring/prometheus/helmrelease-snmp-exporter.yaml))**:
  - [ ] With Synology SNMP polling disabled (`params: []`), `snmp-exporter` runs an idle deployment in the `prometheus` namespace with zero targets. Remove `helmrelease-snmp-exporter.yaml` (and clean up the stale commented-out exporter lines in [`monitoring/victoria-metrics/kustomization.yaml`](./monitoring/victoria-metrics/kustomization.yaml)).

______________________________________________________________________

## 2. Storage, Backups & Volume Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure or have suboptimal volume mount configurations.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which itself runs on a single Longhorn PVC inside the same cluster. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Workloads**:
  - [ ] While `radarr`, `sonarr`, and `prowlarr` store their state in CNPG PostgreSQL + OpenTofu/Recyclarr, critical non-Postgres Longhorn PVCs still rely solely on in-cluster Longhorn volume replicas:
    - [`apps/home-assistant/helmrelease.yaml`](./apps/home-assistant/helmrelease.yaml) (`/config` PVC — `.storage/` integrations and custom components)
    - [`apps/zigbee2mqtt/helmrelease.yaml`](./apps/zigbee2mqtt/helmrelease.yaml) (`/data` PVC — `database.db` device pairings and `coordinator_backup.json`)
    - [`apps/media/qbittorrent/helmrelease.yaml`](./apps/media/qbittorrent/helmrelease.yaml) (`/config` PVC — `BT_backup` active torrent state)
    - [`monitoring/victoria-metrics/vmcluster-influx.yaml`](./monitoring/victoria-metrics/vmcluster-influx.yaml) (`60Gi` PVC — 365-day retention of home-monitoring sensor metrics)
  - [ ] Add Longhorn scheduled backups or [VolSync](https://volsync.readthedocs.io/) replication for these PVCs, and add `retain: true` to the `qbittorrent` and `sabnzbd` `/config` PVCs.
- [ ] **Eliminate Unnecessary Longhorn `ReadWriteMany` (`share-manager`) Overhead & `Multi-Attach` Rollout Risks**:
  - [ ] In [`apps/media/radarr/helmrelease.yaml`](./apps/media/radarr/helmrelease.yaml) and [`apps/media/sonarr/helmrelease.yaml`](./apps/media/sonarr/helmrelease.yaml), the `media-cover` PVC (`/config/MediaCover`) uses `accessMode: ReadWriteMany` even though only the single-replica `main` controller mounts it (`recyclarr` does not mount `media-cover`). Switch `media-cover` to `ReadWriteOnce` with `strategy: Recreate` on `controllers.main` to eliminate two Longhorn NFSv4 `share-manager` pods.
  - [ ] In [`apps/media/qbittorrent/helmrelease.yaml`](./apps/media/qbittorrent/helmrelease.yaml), [`apps/media/sabnzbd/helmrelease.yaml`](./apps/media/sabnzbd/helmrelease.yaml), and [`backends/rustfs/helmrelease.yaml`](./backends/rustfs/helmrelease.yaml), `controllers.main` mounts `ReadWriteOnce` Longhorn PVCs while using the default `RollingUpdate` deployment strategy. Set `strategy: Recreate` (matching `zigbee2mqtt`) to prevent `Multi-Attach error for volume` deadlocks when a rollout schedules the new pod on a different node.
- [ ] **Standardize CloudNativePG (`postgres`) Cluster & Backup Configurations**:
  - [ ] [`backends/ldap/postgres/cluster.yaml`](./backends/ldap/postgres/cluster.yaml) is missing dedicated `walStorage` (`256Mi`) and `replicationSlots.highAvailability.enabled: true` (configured on all other 4 CNPG clusters).
  - [ ] [`apps/home-assistant/postgres/cluster2.yaml`](./apps/home-assistant/postgres/cluster2.yaml) contains a deprecated empty `spec.backup: {}` stanza alongside the `barman-cloud.cloudnative-pg.io` plugin.
  - [ ] [`apps/media/postgres/backup.yaml`](./apps/media/postgres/backup.yaml), [`backends/authelia/postgres/backup.yaml`](./backends/authelia/postgres/backup.yaml), [`backends/ldap/postgres/backup.yaml`](./backends/ldap/postgres/backup.yaml), and [`backends/mqtt/pgmqtt/postgres/backup.yaml`](./backends/mqtt/pgmqtt/postgres/backup.yaml) omit `parameters: { barmanObjectName: postgres }` under `spec.pluginConfiguration` (unlike `apps/home-assistant/postgres/backup2.yaml`), and three of them (`media`, `authelia`, `pgmqtt`) trigger at the exact same second (`0 0 5 * * *`). Stagger their cron schedules and explicitly set `barmanObjectName`.

______________________________________________________________________

## 3. CI/CD, Renovate & Repository Hygiene

- [ ] **Remove Remaining Unreferenced Directories (`blocky` and `mosquitto`)**:
  - [ ] `backends/dns/blocky/` — Commented out in [`backends/dns/kustomization.yaml`](./backends/dns/kustomization.yaml) (`# - blocky`), yet Renovate continues updating its image and [`README.md`](./README.md) still lists Blocky in the architecture diagram and DNS section.
  - [ ] `backends/mqtt/mosquitto/` — Commented out in [`backends/mqtt/kustomization.yaml`](./backends/mqtt/kustomization.yaml) (`# - mosquitto`, superseded by `pgmqtt`), yet Renovate continues updating its image.
- [ ] **Fix Malformed `yaml-language-server` Schema Comments in Root Kustomizations**:
  - [ ] All 6 top-level Flux Kustomization manifests ([`apps.yaml`](./apps.yaml), [`backends.yaml`](./backends.yaml), [`crds.yaml`](./crds.yaml), [`monitoring.yaml`](./monitoring.yaml), [`repos.yaml`](./repos.yaml), [`system.yaml`](./system.yaml)) have a double comment prefix `# # yaml-language-server: $schema=...` on line 1, which prevents `yaml-language-server` from activating schema validation in editors.
