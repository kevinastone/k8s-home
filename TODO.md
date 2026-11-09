# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Off-Cluster Backups & Storage Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure without off-cluster copies.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which now runs as a 3-node distributed cluster on `openebs-rawfile`. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets to satisfy the 3-2-1 backup rule.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Workloads**:
  - [ ] While `radarr`, `sonarr`, and `prowlarr` store their state in CNPG PostgreSQL + OpenTofu/Recyclarr, critical non-Postgres Longhorn PVCs still rely solely on in-cluster Longhorn volume replicas:
    - [`apps/home-assistant/helmrelease.yaml`](./apps/home-assistant/helmrelease.yaml) (`/config` PVC — `.storage/` integrations and custom components)
    - [`apps/zigbee2mqtt/helmrelease.yaml`](./apps/zigbee2mqtt/helmrelease.yaml) (`/data` PVC — `database.db` device pairings and `coordinator_backup.json`)
    - [`monitoring/victoria-metrics/vmcluster-influx.yaml`](./monitoring/victoria-metrics/vmcluster-influx.yaml) (`60Gi` PVC — 365-day retention of home-monitoring sensor metrics)
  - [ ] Add Longhorn scheduled backups or [VolSync](https://volsync.readthedocs.io/) replication for these PVCs.
- [ ] **Harden `dragonfly-operator` CRD Lifecycle & Pin Dragonfly Engine Image**:
  - [ ] [`crds/dragonfly-operator/helmrelease.yaml`](./crds/dragonfly-operator/helmrelease.yaml) sets `values.crds.keep: false` and omits `install.crds: CreateReplace` / `upgrade.crds: CreateReplace`. Set `keep: true` and `crds: CreateReplace` so chart upgrades update CRDs and an accidental chart uninstall cannot cascade-delete `Dragonfly` custom resources.
  - [ ] [`backends/authelia/dragonfly/dragonfly.yaml`](./backends/authelia/dragonfly/dragonfly.yaml) omits `spec.image`, relying on the DragonflyDB version hardcoded in the operator binary. Explicitly pin `spec.image` (and track it via Renovate) so engine updates are managed declaratively.

______________________________________________________________________

## 2. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.
- [ ] **Validate SABnzbd CUE Configuration in [`flake.nix`](./flake.nix)**:
  - [ ] [`apps/media/sabnzbd/helmrelease.yaml`](./apps/media/sabnzbd/helmrelease.yaml) renders `sabnzbd.ini` at pod startup (`init-config`) by running `cue export` against [`apps/media/sabnzbd/resources/sabnzbd.ini/`](./apps/media/sabnzbd/resources/sabnzbd.ini/). Because Kustomize only packages those files into a `ConfigMap`, CUE or YAML schema errors in `sabnzbd.ini/` are not caught by `flate` or `cue vet ./lib/grafana/`.
  - [ ] Expand `checks.cue-vet` in [`flake.nix`](./flake.nix) to run `cue export ./apps/media/sabnzbd/resources/sabnzbd.ini:sabnzbd ...` with placeholder `@tag()` values (`NZBGEEK_API_KEY`, `NEWSHOSTING_USERNAME`, `NEWSHOSTING_PASSWORD`) so broken SABnzbd configs are caught in CI before pod startup.
