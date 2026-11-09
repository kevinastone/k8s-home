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
- [ ] **Add OpenEBS Rawfile LocalPV Capacity & Thin-Provisioning Alerts**:
  - [ ] [`system/openebs/helmrelease.yaml`](./system/openebs/helmrelease.yaml) enables `thinProvision: "true"` and `serviceMonitor.enabled: true` for `openebs-rawfile` (and [`monitoring/openebs/`](./monitoring/openebs/) deploys a Grafana dashboard), but no `PrometheusRule` alerts exist for storage pool or volume exhaustion.
  - [ ] Add a `PrometheusRule` in [`monitoring/openebs/`](./monitoring/openebs/) alerting on low node pool free space (`(rawfile_pool_remaining_capacity_bytes / rawfile_pool_capacity_bytes) < 0.15`), thin-provisioning overcommit (`(rawfile_pool_volumes_logical_bytes / rawfile_pool_capacity_bytes) > 1.0`), and individual volume filesystem usage (`(rawfile_volume_used_bytes / rawfile_volume_total_bytes) > 0.85`).
- [ ] **Harden `dragonfly-operator` CRD Lifecycle & Pin Dragonfly Engine Image**:
  - [ ] [`crds/dragonfly-operator/helmrelease.yaml`](./crds/dragonfly-operator/helmrelease.yaml) sets `values.crds.keep: false` and omits `install.crds: CreateReplace` / `upgrade.crds: CreateReplace`. Set `keep: true` and `crds: CreateReplace` so chart upgrades update CRDs and an accidental chart uninstall cannot cascade-delete `Dragonfly` custom resources.
  - [ ] [`backends/authelia/dragonfly/dragonfly.yaml`](./backends/authelia/dragonfly/dragonfly.yaml) omits `spec.image`, relying on the DragonflyDB version hardcoded in the operator binary. Explicitly pin `spec.image` (and track it via Renovate) so engine updates are managed declaratively.

______________________________________________________________________

## 2. CI/CD, Validation & Automation

- [ ] **Rendered Manifest Diff as Pull Request Comment**:
  - [ ] Update the `diff` job in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml) with `pull-requests: write` permissions to post rendered manifest diffs directly to PR discussion threads alongside `$GITHUB_STEP_SUMMARY`.
  - [ ] Pipe `flate diff all -o github` to both `$GITHUB_STEP_SUMMARY` (supports up to 1MB) and a truncated `diff.patch` artifact (~60,000 chars max) so large chart bumps don't fail the GitHub API's 65,536-character comment limit.
  - [ ] Use `marocchino/sticky-pull-request-comment@v3` with `header: flate-diff` and `path: diff.patch` to upsert a single sticky comment across PR updates and Renovate rebases.
- [ ] **Fix `fix-format` Job Dependency in [`.github/workflows/ci.yaml`](./.github/workflows/ci.yaml)**:
  - [ ] The `fix-format` job specifies `if: github.event_name == 'pull_request' && failure()` without a `needs: [check]` dependency. Because GitHub Actions evaluates `failure()` against upstream jobs in `needs:`, `fix-format` starts in parallel with `check` at workflow start when `failure()` is always `false`, causing `fix-format` to be skipped on every run. Add `needs: [check]` and explicit `permissions: { contents: write }`.
- [ ] **Validate SABnzbd CUE Configuration in [`flake.nix`](./flake.nix)**:
  - [ ] [`apps/media/sabnzbd/helmrelease.yaml`](./apps/media/sabnzbd/helmrelease.yaml) renders `sabnzbd.ini` at pod startup (`init-config`) by running `cue export` against [`apps/media/sabnzbd/resources/sabnzbd.ini/`](./apps/media/sabnzbd/resources/sabnzbd.ini/). Because Kustomize only packages those files into a `ConfigMap`, CUE or YAML schema errors in `sabnzbd.ini/` are not caught by `flate` or `cue vet ./lib/grafana/`.
  - [ ] Expand `checks.cue-vet` in [`flake.nix`](./flake.nix) to run `cue export ./apps/media/sabnzbd/resources/sabnzbd.ini:sabnzbd ...` with placeholder `@tag()` values (`NZBGEEK_API_KEY`, `NEWSHOSTING_USERNAME`, `NEWSHOSTING_PASSWORD`) so broken SABnzbd configs are caught in CI before pod startup.

______________________________________________________________________

## 3. CRD Lifecycle, Flux Dependencies & Workload Hygiene

- [ ] **Resolve Duplicate Gateway API CRD Management ([`crds/gateway-api/`](./crds/gateway-api/) vs. [`system/envoy-gateway/`](./system/envoy-gateway/))**:
  - [ ] [`crds/gateway-api/gateway-api.yaml`](./crds/gateway-api/gateway-api.yaml) reconciles Gateway API CRDs (`v1.7.0`) from `kubernetes-sigs/gateway-api`, while [`system/envoy-gateway/helmrelease.yaml`](./system/envoy-gateway/helmrelease.yaml) (`gateway-helm` `1.9.3`) sets `install.crds: CreateReplace`, `upgrade.crds: CreateReplace`, and `driftDetection.mode: enabled` (which also bundles and applies the `gateway.networking.k8s.io` CRDs). Consolidate Gateway API CRD ownership to a single source so `kustomize-controller` and `helm-controller` do not overwrite each other's CRD versions.
- [ ] **Consolidate `cert-manager` CRD Management & Version Alignment**:
  - [ ] [`crds/cert-manager/kustomization.yaml`](./crds/cert-manager/kustomization.yaml) fetches CRDs remotely from GitHub (`v1.21.1`), which lags behind [`system/cert-manager/helmrelease.yaml`](./system/cert-manager/helmrelease.yaml) (`v1.21.3` with `crds.enabled: false`). Enable `crds.enabled: true` with `install.crds: CreateReplace` and `upgrade.crds: CreateReplace` directly on `system/cert-manager/helmrelease.yaml` and remove `crds/cert-manager/` so CRDs stay version-locked with the controller and offline `kustomize` builds do not require remote GitHub fetches.
- [ ] **Remove Circular Cross-Layer `dependsOn` in [`crds/external-secrets/helmrelease.yaml`](./crds/external-secrets/helmrelease.yaml)**:
  - [ ] `external-secrets` (deployed in the `crds` Flux `Kustomization`) declares `dependsOn: [{ name: cert-manager, namespace: cert-manager }]`, while `cert-manager` is deployed in the `system` Flux `Kustomization` (which itself `dependsOn: [crds]`), and `certManager.enabled` is not enabled on `external-secrets`. Remove the stale `dependsOn` and standardize `install.crds: CreateReplace` / `upgrade.crds: CreateReplace` across [`crds/external-secrets/helmrelease.yaml`](./crds/external-secrets/helmrelease.yaml) and [`crds/argo/helmrelease.yaml`](./crds/argo/helmrelease.yaml).
- [ ] **Decommission Idle KEDA Deployment ([`crds/keda/`](./crds/keda/) & [`monitoring/keda/`](./monitoring/keda/))**:
  - [ ] `keda` runs 3 pods (`keda-operator`, `keda-operator-metrics-apiserver`, `keda-admission-webhooks`), 3 `ServiceMonitor`s, and a Grafana dashboard, but zero `ScaledObject` or `ScaledJob` resources exist in the repository (Argo Events + Argo Workflows handles event-driven transcoding). Remove `crds/keda/` and `monitoring/keda/` if event-driven HPA scaling is no longer needed.

______________________________________________________________________

## 4. Observability, Alerting & Dashboards

- [ ] **Update Deprecated Flux CRD API Versions in `kube-state-metrics` ([`monitoring/victoria-metrics/helmrelease.yaml`](./monitoring/victoria-metrics/helmrelease.yaml))**:
  - [ ] Under `kube-state-metrics.customResourceState.config`, `OCIRepository`, `ImageRepository`, and `ImagePolicy` still target `version: v1beta2` instead of `v1`. Update them to `v1` to match the active Flux v2 API versions.
- [ ] **Exclude Intentionally Suspended Resources from Flux & OpenTofu Failure Alerts**:
  - [ ] In [`monitoring/fluxcd/prometheus-rule.yaml`](./monitoring/fluxcd/prometheus-rule.yaml) (`FluxReconciliationFailure`) and [`monitoring/tofu-controller/prometheus-rule.yaml`](./monitoring/tofu-controller/prometheus-rule.yaml) (`TerraformReconciliationFailed`), add `suspended!="true"` to the `gotk_resource_info{..., ready="False"}` query so intentionally suspended resources do not page when `ready="False"`.
- [ ] **Allow Grafana Sidecar to Prune Deleted Dashboards ([`monitoring/grafana/helmrelease.yaml`](./monitoring/grafana/helmrelease.yaml))**:
  - [ ] `sidecar.dashboards.provider.disableDelete: true` prevents Grafana from removing dashboards from its database when their `ConfigMap`s are deleted in Git. Set `disableDelete: false` so deleted dashboard `ConfigMap`s are automatically pruned without requiring a Grafana pod restart.

______________________________________________________________________

## 5. Configuration & Manifest Cleanup

- [x] **Clean Up Stale `kustomizeconfig.yaml` References & Unused `rustfs` Mounts**:
  - [x] [`monitoring/grafana/kustomizeconfig.yaml`](./monitoring/grafana/kustomizeconfig.yaml): Remove `kustomizeconfig.yaml` and the `configurations:` block from [`monitoring/grafana/kustomization.yaml`](./monitoring/grafana/kustomization.yaml) (no `secretGenerator` or `configMapGenerator` is used in `monitoring/grafana/`).
  - [x] [`backends/authelia/kustomizeconfig.yaml`](./backends/authelia/kustomizeconfig.yaml): Remove dead `Secret` `nameReference` rules (including obsolete `spec/backup/barmanObjectStore/...` paths for `kind: Cluster`).
  - [x] [`backends/rustfs/kustomizeconfig.yaml`](./backends/rustfs/kustomizeconfig.yaml) & [`backends/rustfs/helmrelease.yaml`](./backends/rustfs/helmrelease.yaml): Remove dead `Secret` `nameReference` rules from `kustomizeconfig.yaml` (`rustfs-root-secret` and `rustfs-users` are `ExternalSecret`s, not Kustomize `secretGenerator`s), and remove the unused `persistence.secrets` (`/secrets`) mount and `serviceAccount.rustfs` from `helmrelease.yaml`.
  - [x] [`apps/media/transcoder/`](./apps/media/transcoder/): Remove unreferenced [`scripts/probe.sh`](./apps/media/transcoder/scripts/probe.sh), remove obsolete `kustomizeconfig.yaml` and stale `# replaced by kustomizeconfig` comments from [`workflow-template.yaml`](./apps/media/transcoder/workflow-template.yaml) (since ConfigMap suffix hashing is disabled to prevent workflow failures).
- [x] **Replace Dummy `unifi-health` Pause Pod with Homepage Ping ([`apps/unifi/`](./apps/unifi/))**:
  - [x] [`apps/unifi/deployment.yaml`](./apps/unifi/deployment.yaml) runs a `registry.k8s.io/pause:3.10` pod solely to satisfy `gethomepage.dev/pod-selector: "app.kubernetes.io/name=unifi"` on [`apps/unifi/http-route.yaml`](./apps/unifi/http-route.yaml), which reports healthy even if the external UniFi controller (`192.168.20.1`) is down. Replace `gethomepage.dev/pod-selector` with `gethomepage.dev/ping: "https://192.168.20.1"` and remove `apps/unifi/deployment.yaml`.
- [x] **Simplify `homepage-secrets` Ownership ([`apps/homepage/`](./apps/homepage/))**:
  - [x] [`apps/homepage/secret.yaml`](./apps/homepage/secret.yaml) creates an empty `Secret/homepage-secrets` so [`apps/homepage/external-secret.yaml`](./apps/homepage/external-secret.yaml) can use `creationPolicy: Merge`. Since `media-homepage-secrets` is the sole writer to `homepage-secrets`, switch `creationPolicy: Owner` and remove `apps/homepage/secret.yaml`.
- [x] **Minor Schema, DevShell & Documentation Polish**:
  - [x] Update the legacy schema URL in [`system/reflector/helmrelease.yaml`](./system/reflector/helmrelease.yaml) from `k8s-schemas.freckle.systems` to `k8s-schemas.home-operations.com`.
  - [x] Remove unused `kubectl-rook-ceph` from `devShells.default.packages` in [`flake.nix`](./flake.nix).
  - [x] Replace the hardcoded local `file:///Users/kstone/...` link in [`components/postgres/README.md`](./components/postgres/README.md) with a relative link (`./recovery-cluster.yaml.example`), and update [`apps/media/transcoder/README.md`](./apps/media/transcoder/README.md) to document `nix develop --command opa test apps/media/transcoder/policy/ -v` instead of legacy Docker commands.
