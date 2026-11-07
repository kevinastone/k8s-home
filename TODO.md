# Homelab FluxCD Improvement Recommendations (`TODO.md`)

This document outlines architectural, operational, reliability, and maintainability improvements for the `k8s-home` GitOps repository. Items are grouped by domain and ordered by impact.

______________________________________________________________________

## 1. High-Availability Distributed S3 (`rustfs`) Migration

Currently, `rustfs` runs as a single-replica `Deployment` backed by one `100Gi` Longhorn PVC (~3.4 GiB used), meaning S3 availability depends on a single pod and Longhorn network block replication. Migrating to a 3-node distributed `StatefulSet` on local `openebs-hostpath` storage removes Longhorn overhead and allows `rustfs` to handle redundancy natively via Reed-Solomon erasure coding while tolerating the complete loss of any 1 node (out of 3).

- [x] **1. Erasure Coding & Drive Topology (3 Nodes × 1 Drive = 3 Drives Total)**:
  - RustFS supports erasure sets from 2 to 16 drives. For 3 nodes ($N = 3$), a 1-drive-per-node layout matches the physical disk topology (each node has 1 NVMe), avoiding artificial subpath splitting on the same device.
  - Provision **1 `openebs-hostpath` PVC per pod** (`data`) across **3 StatefulSet replicas** (3 nodes × 1 drive/node = 3 drives total, `N = 3`).
  - Configure **2-data / 1-parity (`EC:1`)** via `RUSTFS_ERASURE_SET_DRIVE_COUNT: "3"` and `RUSTFS_STORAGE_CLASS_STANDARD: "EC:1"`:
    - **Read Quorum:** `K = 2` drives.
    - **Write Quorum:** `K = 2` drives.
    - **Single-Node Failure Tolerance:** Losing 1 full node takes 1 drive offline, leaving **exactly 2 drives online** across the remaining 2 nodes—satisfying both read quorum (2) and write quorum (2) for continuous operations.
    - **Sizing:** One `50Gi` PVC per pod (3 × `50Gi` = `150Gi` raw across the cluster) provides **`100Gi` usable S3 capacity** at 66.7% `EC:1` efficiency (compared to ~1.3 GiB currently used).
- [x] **2. Manifest Changes in [`backends/rustfs/helmrelease.yaml`](./backends/rustfs/helmrelease.yaml)**:
  - [x] **StatefulSet Controller:** Change `controllers.main` to `type: statefulset`, `replicas: 3`, and set `statefulset.podManagementPolicy: Parallel` (required so all 3 pods start concurrently and discover peers without deadlocking on `OrderedReady` quorum checks).
  - [x] **Strict Node Anti-Affinity:** Add `pod.affinity.podAntiAffinity.requiredDuringSchedulingIgnoredDuringExecution` on `topologyKey: kubernetes.io/hostname` so `rustfs-0`, `rustfs-1`, and `rustfs-2` are guaranteed to schedule onto the 3 distinct cluster nodes. Because `openebs-hostpath` uses `volumeBindingMode: WaitForFirstConsumer`, each pod's local PV automatically binds to its assigned node.
  - [x] **Peer Discovery & Networking:** Set `publishNotReadyAddresses: true` on the `rustfs` service exposing port `9000` (`s3`) so pods can resolve `rustfs-{0...2}.rustfs.rustfs.svc.cluster.local` during initial cluster formation before readiness probes succeed.
  - [x] **Distributed Volume Arguments & Env:** Set `RUSTFS_VOLUMES` to `http://rustfs-{0...2}.rustfs.rustfs.svc.cluster.local:9000/data`, `RUSTFS_ERASURE_SET_DRIVE_COUNT: "3"`, and `RUSTFS_STORAGE_CLASS_STANDARD: "EC:1"` under `env`.
  - [x] **Volume Claim Templates:** Replace `persistence.data` with one `statefulset.volumeClaimTemplates` (`data` mounted at `/data`) using `storageClass: openebs-hostpath`, `accessMode: ReadWriteOnce`, and `size: 50Gi`.
- [x] **3. Migration & Cutover Plan**:
  - RustFS cannot convert a standalone single-disk `/data` directory into a multi-node erasure-coded format in-place.
  - [x] **Executed Option B (Zero-History-Loss Mirror):** Copied 1.28 GiB of existing S3 bucket contents (`postgres` and `dragonfly`) locally using `rclone`, deployed the 3-node StatefulSet, reconciled OpenTofu buckets and policies, and restored objects back in so Barman WAL timelines remained uninterrupted. Old `100Gi` Longhorn PVC (`rustfs`) is ready for decommission.

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
