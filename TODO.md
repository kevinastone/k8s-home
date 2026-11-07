# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. High-Availability Distributed S3 (`rustfs`) Migration

Currently, `rustfs` runs as a single-replica `Deployment` backed by one `100Gi` Longhorn PVC (~3.4 GiB used), meaning S3 availability depends on a single pod and Longhorn network block replication. Migrating to a 3-node distributed `StatefulSet` on local `openebs-hostpath` storage removes Longhorn overhead and allows `rustfs` to handle redundancy natively via Reed-Solomon erasure coding while tolerating the complete loss of any 1 node (out of 3).

- [ ] **1. Erasure Coding & Drive Topology (3 Nodes × 2 Drives = 6 Drives Total)**:
  - RustFS erasure coding (`ecstore`) requires an even number of drives (`>= 4`) per erasure set and enforces parity `M <= N / 2`. A 3-node cluster with only 1 drive per node (`N = 3`) cannot form a symmetric erasure set that survives a node loss.
  - Provision **2 `openebs-hostpath` PVCs per pod** (`vol0` and `vol1`) across **3 StatefulSet replicas** (3 nodes × 2 drives/node = 6 drives total, `N = 6`).
  - Configure **4-data / 2-parity (`EC:2`)** via `RUSTFS_ERASURE_SET_DRIVE_COUNT: "6"` and `RUSTFS_STORAGE_CLASS_STANDARD: "EC:2"`:
    - **Read Quorum:** `K = 4` drives.
    - **Write Quorum:** `K = 4` drives.
    - **Single-Node Failure Tolerance:** Losing 1 full node takes 2 drives offline, leaving **exactly 4 drives online** across the remaining 2 nodes—satisfying both read quorum (4) and write quorum (4) for continuous operations (analogous to RAID 5 degradation during drive replacement/reboot).
    - **Sizing:** Two `25Gi` PVCs per pod (6 × `25Gi` = `150Gi` raw across the cluster) provides **`100Gi` usable S3 capacity** at 66.7% `EC:2` efficiency (compared to ~3.4 GiB currently used).
- [ ] **2. Manifest Changes in [`backends/rustfs/helmrelease.yaml`](./backends/rustfs/helmrelease.yaml)**:
  - [ ] **StatefulSet Controller:** Change `controllers.main` to `type: statefulset`, `replicas: 3`, and set `statefulset.podManagementPolicy: Parallel` (required so all 3 pods start concurrently and discover peers without deadlocking on `OrderedReady` quorum checks).
  - [ ] **Strict Node Anti-Affinity:** Add `pod.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution` on `topologyKey: kubernetes.io/hostname` so `rustfs-0`, `rustfs-1`, and `rustfs-2` are guaranteed to schedule onto the 3 distinct cluster nodes. Because `openebs-hostpath` uses `volumeBindingMode: WaitForFirstConsumer`, each pod's local PVs will automatically bind to its assigned node.
  - [ ] **Headless Service for Peer Discovery:** Add a `headless` service (`clusterIP: None`, `publishNotReadyAddresses: true`) exposing port `9000` (`s3`) so pods can resolve `rustfs-{0...2}.rustfs-headless.rustfs.svc.cluster.local` during initial cluster formation before readiness probes succeed.
  - [ ] **Distributed Volume Arguments & Env:** Update container `args` (or `RUSTFS_VOLUMES`) from `["/data"]` to brace-expansion syntax across all 3 pods and 2 local mounts:
    ```yaml
    args:
      - http://rustfs-{0...2}.rustfs-headless.rustfs.svc.cluster.local:9000/data/vol{0...1}
    ```
    and add `RUSTFS_ERASURE_SET_DRIVE_COUNT: "6"` and `RUSTFS_STORAGE_CLASS_STANDARD: "EC:2"` under `env`.
  - [ ] **Volume Claim Templates:** Replace `persistence.data` with two `statefulset.volumeClaimTemplates` (`vol0` mounted at `/data/vol0` and `vol1` mounted at `/data/vol1`) using `storageClass: openebs-hostpath`, `accessMode: ReadWriteOnce`, and `size: 25Gi`.
- [ ] **3. Migration & Cutover Plan**:
  - RustFS cannot convert a standalone single-disk `/data` directory into a multi-node erasure-coded format in-place.
  - [ ] **Option A (In-Place Re-initialize + Fresh Base Backups):** Deploy the 3-node StatefulSet, re-run the [`backends/rustfs/terraform.yaml`](./backends/rustfs/terraform.yaml) OpenTofu job to provision the `postgres` and `dragonfly` buckets/users on the new cluster, bump `serverName` (or trigger `kubectl cnpg backup`) on the 5 CNPG clusters to start a fresh Barman WAL timeline, and delete the old `100Gi` Longhorn PVC (`rustfs`).
  - [ ] **Option B (Zero-History-Loss Mirror):** Temporarily copy the 3.4 GiB of existing S3 bucket contents (`postgres` and `dragonfly`) out using `rclone` or `mc mirror`, switch `rustfs` to the 3-node StatefulSet + re-apply OpenTofu buckets, mirror the objects back in so existing Barman WAL timelines remain contiguous, and delete the old Longhorn PVC.

______________________________________________________________________

## 2. Off-Cluster Backups & Volume Reliability

While CloudNativePG (`postgres`) and `dragonfly` back up to the in-cluster `rustfs` S3 service, several stateful workloads and the S3 store itself represent single points of failure without off-cluster copies.

- [ ] **Off-Cluster / 3-2-1 Backup Strategy for `rustfs` and Longhorn**:
  - [ ] `postgres` (Barman) and `dragonfly` back up to `s3.k8s.kevinastone.com` (`rustfs`), which itself runs on a single Longhorn PVC inside the same cluster. Add an off-cluster replication job (e.g., `rclone` CronJob or Backblaze B2 / Synology NAS sync) for `rustfs` buckets.
  - [ ] Configure a Longhorn `backupTarget` (e.g., SMB/NFS share on the Synology NAS or external S3) and add a `RecurringJob` with `task: backup` in [`monitoring/longhorn/recurringjob.yaml`](./monitoring/longhorn/recurringjob.yaml) (currently only `snapshot-cleanup` and `filesystem-trim` exist).
- [ ] **Stateful PVC Backups for Non-Postgres Workloads**:
  - [ ] While `radarr`, `sonarr`, and `prowlarr` store their state in CNPG PostgreSQL + OpenTofu/Recyclarr, critical non-Postgres Longhorn PVCs still rely solely on in-cluster Longhorn volume replicas:
    - [`apps/home-assistant/helmrelease.yaml`](./apps/home-assistant/helmrelease.yaml) (`/config` PVC — `.storage/` integrations and custom components)
    - [`apps/zigbee2mqtt/helmrelease.yaml`](./apps/zigbee2mqtt/helmrelease.yaml) (`/data` PVC — `database.db` device pairings and `coordinator_backup.json`)
    - [`monitoring/victoria-metrics/vmcluster-influx.yaml`](./monitoring/victoria-metrics/vmcluster-influx.yaml) (`60Gi` PVC — 365-day retention of home-monitoring sensor metrics)
  - [ ] Add Longhorn scheduled backups or [VolSync](https://volsync.readthedocs.io/) replication for these PVCs.
