# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. Off-Cluster Backups & Storage Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service and `kopiur` backs up key Longhorn PVCs to the NAS over SMB, several storage paths can be hardened further.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs`**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which runs as a 3-node distributed erasure-coded cluster on `openebs-rawfile`. Add an off-cluster replication job (e.g., `rclone` CronJob to the NAS SMB share or Backblaze B2) for `rustfs` buckets to satisfy the 3-2-1 backup rule.
- [ ] **Extend `components/kopiur` Backups to Remaining Stateful Media PVCs**:
  - [ ] Include [`components/kopiur`](./components/kopiur/kustomization.yaml) in [`apps/media/kustomization.yaml`](./apps/media/kustomization.yaml) and add the `kopiur.home-operations.com/backup: "true"` label to the `config` PVCs in [`apps/media/qbittorrent/helmrelease.yaml`](./apps/media/qbittorrent/helmrelease.yaml) (which holds `/config/qBittorrent/BT_backup` `.torrent` and `.fastresume` state) and [`apps/media/sabnzbd/helmrelease.yaml`](./apps/media/sabnzbd/helmrelease.yaml) (queue/history state).
- [ ] **Optimize VictoriaLogs Storage & High Availability**:
  - [ ] **Migrate VictoriaLogs from `vlsingle` (Longhorn) to Clustered / Replicated HA on `openebs-rawfile`**:
    - [`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml) currently runs `vlsingle` with a single `50Gi` replicated Longhorn PVC (`vlsingle-vm-stack`).
    - Because `openebs-rawfile` binds PVs to a single physical host (`nodeAffinity`), running a single instance on `openebs-rawfile` would cause VictoriaLogs to be unavailable whenever that node is drained or offline.
    - To combine local NVMe speed (`openebs-rawfile`) with resilience, migrate from `vlsingle` to **`vlcluster`** (using `vlinsert`, `vlselect`, and multi-node `vlstorage` on `openebs-rawfile`) or run **dual mirrored `vlsingle` instances** paired with dual-write in [`monitoring/vector/helmrelease-agent.yaml`](./monitoring/vector/helmrelease-agent.yaml) (`sinks.vlogs`) and `vmauth` failover, so log ingestion and search remain available across host restarts.

______________________________________________________________________

## 2. Kustomize Components, Templating & DRY Opportunities

- [ ] **Consolidate `recyclarr` & Media OpenTofu**:
  - [ ] **Consolidate Dual Always-On `recyclarr` Deployments into a Single `CronJob`**: [`apps/media/radarr/helmrelease.yaml`](./apps/media/radarr/helmrelease.yaml) and [`apps/media/sonarr/helmrelease.yaml`](./apps/media/sonarr/helmrelease.yaml) each run an always-on `recyclarr` Deployment controller sleeping on `CRON_SCHEDULE: "@daily"`. Because Recyclarr natively syncs multiple `radarr:` and `sonarr:` instances from a single config file, consolidate both into a single Kubernetes `CronJob` (`type: cronjob`, matching `orphan-cleanup` in `qbittorrent`) to eliminate two idle long-running pods.
  - [ ] **Consolidate Media OpenTofu Modules (`prowlarr`, `radarr`, `sonarr`)**: Currently 3 separate `Terraform` CRs in [`apps/media/`](./apps/media/) spawn 3 `tf-runner` pods every 10 minutes with duplicated `varsFrom` (`sabnzbd-secret`, `nzbgeek-secret`) and duplicated NZBGeek/SABnzbd resources across [`radarr/tofu/main.tf`](./apps/media/radarr/tofu/main.tf) and [`sonarr/tofu/main.tf`](./apps/media/sonarr/tofu/main.tf). Consolidate into a single `apps/media/tofu/` module (or use `prowlarr_application_radarr` / `prowlarr_application_sonarr` to sync indexers from Prowlarr) to cut `tofu-controller` runner pods and state secrets from 3 to 1.

______________________________________________________________________

## 3. Secrets Management & FluxCD Lifecycle Architecture

- [ ] **Fix Cold-Bootstrap Dependency Inversion Between `system` `ExternalSecret`s and `backends/one-password`**:
  - [ ] [`backends.yaml`](./backends.yaml) depends on [`system.yaml`](./system.yaml) (`dependsOn: [system]`), yet 5 directories in `system/` (`cert-manager`, `external-dns`, `csi-driver-smb`, `kopiur`, `tailscale-operator`) create `ExternalSecret`s targeting `ClusterSecretStore/one-password`, which is deployed later in [`backends/one-password/`](./backends/one-password/kustomization.yaml).
  - [ ] Move `one-password` into `system/one-password/` (or a dedicated stage between `crds` and `system`) so `ClusterSecretStore/one-password` is ready before `system` workloads reconcile, and deduplicate the byte-for-byte identical [`system/cert-manager/cloudflare-api-token-secret.yaml`](./system/cert-manager/cloudflare-api-token-secret.yaml) and [`system/external-dns/cloudflare-api-token-secret.yaml`](./system/external-dns/cloudflare-api-token-secret.yaml).
- [ ] **Unify `cert-manager` & `envoy-gateway` CRD Management with Other Operators**:
  - [ ] Unlike all other operators in `crds/`, [`crds/cert-manager/crds.yaml`](./crds/cert-manager/crds.yaml) and [`crds/envoy-gateway/crds.yaml`](./crds/envoy-gateway/crds.yaml) clone full upstream Git repositories via `GitRepository` + nested Flux `Kustomization`s while their `HelmRelease`s run in `system/` with `crds: Skip`, requiring custom `groupName` rules in [`.github/renovate.jsonc`](./.github/renovate.jsonc) to prevent version skew.
  - [ ] Move the `cert-manager` and `envoy-gateway` controller `HelmRelease`s into `crds/` with `crds: CreateReplace` (leaving `ClusterIssuer`, `GatewayClass`, and `Gateway` CRs in `system/`) to eliminate 2 `GitRepository` clones, 2 extra Flux `Kustomization`s, and 24 lines of Renovate grouping rules.

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

______________________________________________________________________

## 6. Backends & Services

- [ ] **Evaluate Zot `ui` and `search` Extensions**:
  - [ ] Decide whether to enable `"search": { "enable": true }` and `"ui": { "enable": true }` in [`backends/zot/resources/config.json`](./backends/zot/resources/config.json) for browsing cached repositories, tags, and manifests at `https://zot.k8s.kevinastone.com`.
  - [ ] If enabled, split [`backends/zot/http-route.yaml`](./backends/zot/http-route.yaml) into separate `HTTPRoute`s so the OCI registry API (`/v2`) stays on `public-gateway` (unauthenticated for CRI-O pulls) while the web UI (`/`) is routed through `auth-gateway` (Authelia-protected), plus optional `gethomepage.dev/*` annotations.
