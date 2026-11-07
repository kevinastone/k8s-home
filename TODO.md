# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, security, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and roughly ordered by impact.

______________________________________________________________________

## 1. Storage, Backups & Disaster Recovery

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which itself runs on a Longhorn PVC inside the same cluster. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in `monitoring/longhorn/recurringjob.yaml` (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Apps**:
  - [ ] Critical stateful configurations on Longhorn PVCs (`home-assistant` `/config`, `zigbee2mqtt`, `radarr`, `sonarr`, `prowlarr`, `qbittorrent`) rely solely on Longhorn volume replicas. Add either Longhorn scheduled volume backups or [VolSync](https://volsync.readthedocs.io/) replication to external storage.
