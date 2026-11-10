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
    - To combine local NVMe speed (`openebs-rawfile`) with resilience, migrate from `vlsingle` to **`vlcluster`** (using `vlinsert`, `vlselect`, and multi-node `vlstorage` on `openebs-rawfile`) or run **dual mirrored `vlsingle` instances** paired with dual-write in [`monitoring/vector/helmrelease.yaml`](./monitoring/vector/helmrelease.yaml) (`sinks.vlogs`) and `vmauth` failover, so log ingestion and search remain available across host restarts.

______________________________________________________________________

## 2. Monorepo Tooling, Nix Modularization & Testing Encapsulation

Currently, [`flake.nix`](./flake.nix) defines all domain-specific checks (`opa-test`, `regal-lint`, `cue-vet`, `dashboards-in-sync`, `renovate-config`), custom script wrappers (`build-dashboards`), and a monolithic 20-package `devShells.default` in a single root file. Encapsulating checks and tools into their respective sub-directories will keep the root flake minimal and make sub-projects self-contained.

- [x] **Adopt Per-Directory Nix Modules (`flake-parts` or Sub-Directory `default.nix` Discovery)**:
  - [x] Refactor [`flake.nix`](./flake.nix) into a thin root aggregator (~60 lines) that configures `treefmt`, provides core cluster CLI tools (`kubectl`, `fluxcd`, `kustomize`, `sops`, `age`, `kubectl-cnpg`), and merges `{ checks, packages, devShells }` imported from domain sub-directories:
    - [x] **`apps/media/transcoder/default.nix`**: Encapsulate `open-policy-agent`, `regal`, `shellcheck`, and `jq`. Export `checks.transcoder-opa-test`, `checks.transcoder-regal-lint`, and a new `checks.transcoder-shellcheck` (validating [`apps/media/transcoder/scripts/*.sh`](./apps/media/transcoder/scripts/transcode.sh)), with required packages automatically aggregated into the root devShell.
    - [x] **`apps/media/sabnzbd/default.nix`**: [`apps/media/sabnzbd/resources/sabnzbd.ini/`](./apps/media/sabnzbd/resources/sabnzbd.ini/main.cue) defines an 8-file CUE package (`package sabnzbd`) evaluated at pod startup by an `init-config` container, but it is currently untested in CI. Add a `checks.sabnzbd-config-vet` target that runs `cue export` with mock `-t` tag variables (`NZBGEEK_API_KEY`, `NEWSHOSTING_USERNAME`, `NEWSHOSTING_PASSWORD`) to catch schema and YAML errors before deployment.
    - [x] **`monitoring/grafana/default.nix` & `cue/grafana` (Dashboard Subsystem)**: Encapsulate `build-dashboards` (`writeNuBin`), `download-dashboards` (wrapping [`monitoring/grafana/scripts/download_dashboards.py`](./monitoring/grafana/scripts/download_dashboards.py)), `checks.cue-vet` (validating [`cue/grafana/`](./cue/grafana/)), and `checks.dashboards-in-sync`, with tools automatically aggregated into the root devShell.
    - [x] **`.github/default.nix` (Isolate Renovate Closure)**: Move `checks.renovate-config` and `pkgs.renovate` out of the root `devShells.default` into `.github/default.nix` so entering the repo root does not pull the heavy Node.js closure on every `nixpkgs` update.
    - [x] **OpenTofu Validation Module (`nix/tofu.nix`)**: Create a `checks.tofu-lint` flake check that statically validates all 5 OpenTofu directories (`backends/rustfs/tofu`, `backends/ldap/tofu`, `apps/media/prowlarr/tofu`, `apps/media/radarr/tofu`, `apps/media/sonarr/tofu`) using `tflint --recursive`.
- [ ] **Prune Unused Vendored Schemas in `cue.mod/`**:
  - [ ] [`cue.mod/pkg/github.com/grafana/grafana/`](./cue.mod/README.md) currently tracks 212 files, ~174 of which are unused upstream Grafana `apps/*` (`advisor`, `iam`, `shorturl`, etc.), `datasource/*` (`azuremonitor`, `cloudwatch`), and `pkg/**/testdata/*` schemas. Prune `cue.mod/` down to the ~38 files actually imported by [`cue/grafana/`](./cue/grafana/dashboards.cue) (`kinds/dashboard`, `packages/grafana-schema/src/common`, and `public/app/plugins/panel/*`) and tighten the tarball extraction globs in [`cue.mod/README.md`](./cue.mod/README.md).

______________________________________________________________________

## 3. Repository Organization & Kustomize Architecture

- [ ] **Extract Duplicated Manifests into Reusable Kustomize `components/`**:
  - [ ] **`components/tf-runner` (OpenTofu RBAC)**: The 28-line `tf-runner` RBAC block (`ServiceAccount`, `Role`, `RoleBinding`) is duplicated across [`backends/rustfs/terraform.yaml`](./backends/rustfs/terraform.yaml), [`backends/ldap/terraform.yaml`](./backends/ldap/terraform.yaml), and the bottom of [`apps/media/sonarr/terraform.yaml`](./apps/media/sonarr/terraform.yaml) (making `prowlarr` and `radarr` implicitly depend on `sonarr`'s manifest for their shared runner `ServiceAccount` in the `media` namespace). Extract `tf-runner` into `components/tf-runner/` and include it at the namespace level (`apps/media/kustomization.yaml`, `backends/rustfs/kustomization.yaml`, `backends/ldap/kustomization.yaml`).
  - [ ] **`components/kustomizeconfig` (Consolidate 17 Boilerplate `kustomizeconfig.yaml` Files)**: 17 directories across `apps/`, `backends/`, `monitoring/`, and `system/` maintain nearly identical `kustomizeconfig.yaml` files to configure `nameReference` for `HelmRelease` persistence mounts. Replace them with a single shared `kustomizeconfig.yaml` using wildcard fieldSpecs (`spec/values/persistence/*/name`) or a shared Kustomize component.
  - [ ] **Expand `components/postgres` with Base CNPG Templates**: [`components/postgres/`](./components/postgres/kustomization.yaml) currently only contains `s3-creds.yaml`, while all 5 PostgreSQL directories (`apps/media/postgres`, `apps/home-assistant/postgres`, `backends/authelia/postgres`, `backends/ldap/postgres`, `backends/mqtt/pgmqtt/postgres`) duplicate ~90% identical `cluster.yaml`, `backup.yaml`, and `objectstore.yaml` manifests (leading to drift such as missing `walStorage` in [`backends/ldap/postgres/cluster.yaml`](./backends/ldap/postgres/cluster.yaml) and `cluster2.yaml`/`backup2.yaml` naming in [`apps/home-assistant/postgres/`](./apps/home-assistant/postgres/kustomization.yaml)). Move base `Cluster`, `ScheduledBackup`, and `ObjectStore` definitions into `components/postgres/` and apply per-app Kustomize patches for database names, S3 paths, and storage sizes.
- [ ] **Standardize Service vs. `monitoring/` Directory Boundaries**:
  - [ ] **Co-locate Service Dashboards, Alerts & Maintenance Jobs**: Currently, some services co-locate their `dashboards/` and `prometheus-rule.yaml` inside their own directory (`system/cert-manager/`, `system/longhorn/`, `backends/rustfs/`, `backends/authelia/`), while others split them into `monitoring/<service>/` (`monitoring/argo/`, `monitoring/dragonfly/`, `monitoring/envoy-gateway/`, `monitoring/external-secrets/`, `monitoring/openebs/`, `monitoring/tofu-controller/`). Because `PrometheusRule` and `PodMonitor` CRDs are already reconciled in the `crds` stage prior to `system`, `backends`, and `apps`, co-locating `dashboards/`, `pod-monitor.yaml`, and `prometheus-rule.yaml` directly within each service's directory simplifies navigation and keeps `monitoring/` focused strictly on the observability stack (`victoria-metrics`, `grafana`, `vector`, `prometheus`, `goldilocks`).
  - [ ] **Move Longhorn `RecurringJob`s out of `monitoring/longhorn/`**: [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) defines storage maintenance jobs (`snapshot-cleanup`, `filesystem-trim`) inside `monitoring/` rather than [`system/longhorn/`](./system/longhorn/kustomization.yaml). Move `recurringjob.yaml` into `system/longhorn/` (decoupling Longhorn CRD installation if needed) and remove `monitoring/longhorn/`.
  - [ ] **Align `apps/home-monitoring/` and `monitoring/{network-ups-tools,peanut}`**: [`apps/home-monitoring/`](./apps/home-monitoring/kustomization.yaml) lives under `apps/` despite only containing a `Namespace` and a Grafana dashboard (`dashboards/home.cue`), whereas [`monitoring/network-ups-tools/`](./monitoring/network-ups-tools/kustomization.yaml) and [`monitoring/peanut/`](./monitoring/peanut/kustomization.yaml) deploy UPS daemon/web workloads under `monitoring/`. Standardize where hardware monitoring workloads and standalone dashboards reside.
- [ ] **Consolidate Single-Use `HelmRepository` Sources in `repos/helm/`**:
  - [ ] Following the migration to inline `spec.chart.kind: OCIRepository` in most `HelmRelease` manifests, [`repos/helm/`](./repos/helm/kustomization.yaml) still holds 8 single-consumer `HelmRepository` definitions. Migrate charts that publish official OCI artifacts (`descheduler`, `external-dns`, `metrics-server`, `tailscale`) to inline `OCIRepository` specs, or co-locate single-consumer `HelmRepository` resources with their `HelmRelease`, keeping only shared repositories (`bjw-s-labs.yaml`, `fairwinds.yaml`) in `repos/helm/`.

______________________________________________________________________

## 4. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.
