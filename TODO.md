# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Off-Cluster Backups & Storage Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure without off-cluster copies.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which now runs as a 3-node distributed erasure-coded cluster on `openebs-rawfile`. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets to satisfy the 3-2-1 backup rule.
- [ ] **Optimize VictoriaLogs Storage & High Availability**:
  - [ ] **Migrate VictoriaLogs from `vlsingle` (Longhorn) to Clustered / Replicated HA on `openebs-rawfile`**:
    - [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) currently runs `vlsingle` with a single `50Gi` replicated Longhorn PVC (`vlsingle-vm-stack`).
    - Because `openebs-rawfile` binds PVs to a single physical host (`nodeAffinity`), running a single instance on `openebs-rawfile` would cause VictoriaLogs to be unavailable whenever that node is drained or offline.
    - To combine local NVMe speed (`openebs-rawfile`) with resilience, migrate from `vlsingle` to **`vlcluster`** (using `vlinsert`, `vlselect`, and multi-node `vlstorage` on `openebs-rawfile`) or run **dual mirrored `vlsingle` instances** paired with dual-write in [`monitoring/vector/helmrelease-agent.yaml`](./monitoring/vector/helmrelease-agent.yaml) (`sinks.vlogs`) and `vmauth` failover, so log ingestion and search remain available across host restarts.

______________________________________________________________________

## 2. Repository Organization & Kustomize Architecture

- [ ] **Standardize Service vs. `monitoring/` Directory Boundaries**:
  - [ ] **Co-locate Service Dashboards, Alerts & Maintenance Jobs**: Currently, some services co-locate their `dashboards/` and `prometheus-rule.yaml` inside their own directory (`system/cert-manager/`, `system/longhorn/`, `backends/rustfs/`, `backends/authelia/`), while others split them into `monitoring/<service>/` (`monitoring/argo/`, `monitoring/dragonfly/`, `monitoring/envoy-gateway/`, `monitoring/external-secrets/`, `monitoring/openebs/`, `monitoring/tofu-controller/`). Because `PrometheusRule` and `PodMonitor` CRDs are already reconciled in the `crds` stage prior to `system`, `backends`, and `apps`, co-locating `dashboards/`, `pod-monitor.yaml`, and `prometheus-rule.yaml` directly within each service's directory simplifies navigation and keeps `monitoring/` focused strictly on the observability stack (`victoria-metrics`, `grafana`, `vector`, `prometheus`, `goldilocks`).
  - [ ] **Move Longhorn `RecurringJob`s out of `monitoring/longhorn/`**: [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) defines storage maintenance jobs (`snapshot-cleanup`, `filesystem-trim`) inside `monitoring/` rather than [`system/longhorn/`](./system/longhorn/kustomization.yaml). Move `recurringjob.yaml` into `system/longhorn/` (decoupling Longhorn CRD installation if needed) and remove `monitoring/longhorn/`.
  - [ ] **Align `apps/home-monitoring/` and `monitoring/{network-ups-tools,peanut}`**: [`apps/home-monitoring/`](./apps/home-monitoring/kustomization.yaml) lives under `apps/` despite only containing a `Namespace` and a Grafana dashboard (`dashboards/home.cue`), whereas [`monitoring/network-ups-tools/`](./monitoring/network-ups-tools/kustomization.yaml) and [`monitoring/peanut/`](./monitoring/peanut/kustomization.yaml) deploy UPS daemon/web workloads under `monitoring/`. Standardize where hardware monitoring workloads and standalone dashboards reside.

______________________________________________________________________

## 3. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.
