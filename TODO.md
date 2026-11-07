# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Observability, Alerting & Dashboards

Several alerting rules and dashboards have subtle metric or datasource mismatches following recent migrations (Flux v2.1+ metric changes, Loki to VictoriaLogs, and Synology SNMP removal).

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
