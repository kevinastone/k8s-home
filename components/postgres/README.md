# CloudNativePG (CNPG) Architecture & Recovery Runbook

This directory contains shared components, templates, and operational runbooks for CloudNativePG clusters across the homelab.

______________________________________________________________________

## Architecture Overview

- **Engine**: PostgreSQL 17 (CloudNativePG operator).
- **Topology**: 3 instances per cluster configured with Pod Anti-Affinity across worker nodes.
- **Local Storage**: `openebs-hostpath` for low-latency NVMe performance (`storage` and `walStorage`).
- **Object Storage & Backups**:
  - Managed by the `barman-cloud.cloudnative-pg.io` plugin.
  - Continuous WAL archiving and scheduled physical base backups (`ScheduledBackup`) stream to `rustfs` S3 (`s3.k8s.kevinastone.com`).
  - S3 credentials are synchronized across namespaces using the `components/postgres` kustomize component via `ClusterSecretStore/rustfs-kubernetes-store`.

______________________________________________________________________

## Disaster Recovery & Point-in-Time Recovery (PITR) Runbook

In CloudNativePG, **a cluster's bootstrap method cannot be modified in-place** after creation. Recovery is executed by declaring a new `Cluster` resource that bootstraps from an existing backup in object storage (`spec.bootstrap.recovery`).

### Scenario 1: Full Cluster Disaster Recovery (Latest Available Backup)

Use this scenario if storage was lost, nodes failed irrecoverably, or the active database cluster needs to be rebuilt from the latest WAL state.

1. **Copy the recovery template**:
   Copy \[`recovery-cluster.yaml.example`\](file:///Users/kstone/Documents/k8s-home/components/postgres/recovery-cluster.yaml.example) into the application's postgres directory (e.g., `apps/<app>/postgres/cluster-restored.yaml`).

1. **Configure the new cluster**:

   - Set `metadata.name` to a fresh name (e.g. `postgres-v2` or `postgres-restored`).
   - Match the storage size and resource limits of the original cluster.
   - Verify `spec.externalClusters[0].plugin.parameters.barmanObjectName` matches the local `ObjectStore` resource name.
   - Verify `spec.externalClusters[0].plugin.parameters.serverName` matches the backup directory in S3.

1. **Deploy via GitOps**:

   - Add the new manifest to `kustomization.yaml` in the app's postgres folder.
   - Commit and push to Git.

1. **Verify bootstrap and data replication**:
   Run read-only inspection commands to monitor initialization:

   ```bash
   # Check CNPG cluster state
   kubectl cnpg status <new-cluster-name> -n <namespace>

   # View recovery and bootstrap progress
   kubectl logs -n <namespace> <new-cluster-name>-1 -c bootstrap -f
   ```

   Wait until all 3 instances report `Cluster in healthy state`.

1. **Cutover Application**:

   - Point application configurations to the new service endpoint: `<new-cluster-name>-rw.<namespace>.svc.cluster.local`.
   - Update application secret references to the new credentials secret: `<new-cluster-name>-app`.
   - Enable `plugins` on the new cluster to resume WAL archiving to Barman.
   - Point `ScheduledBackup` to `<new-cluster-name>`.

1. **Decommission Old Cluster**:

   - Once verified, remove the failed cluster manifest from `kustomization.yaml`.

______________________________________________________________________

### Scenario 2: Point-in-Time Recovery (PITR)

Use this scenario if accidental data deletion, schema corruption, or a bad migration occurred, and you need to restore the database to an exact moment before the incident.

1. **Identify the target timestamp (in UTC)**:
   Determine the exact target time before the issue occurred (e.g. `"2026-11-06 07:00:00.000000+00"`).

1. **Configure `recoveryTarget`**:
   In your recovery cluster manifest, uncomment and populate `spec.bootstrap.recovery.recoveryTarget`:

   ```yaml
   bootstrap:
     recovery:
       source: s3-backup
       recoveryTarget:
         targetTime: "2026-11-06 07:00:00.000000+00"
   ```

1. **Deploy, verify, and cut over**:
   Follow steps 3 through 6 from Scenario 1 above.

______________________________________________________________________

### Scenario 3: Forking / Verification Testing

To test backup integrity or inspect data without impacting the production cluster:

1. Create a temporary cluster manifest (e.g. `postgres-test`) pointing to the production backup source via `spec.externalClusters`.
1. Do **not** enable WAL archiving (`isWALArchiver: true`) on the test cluster, so it does not overwrite production WAL archives.
1. Once verification is complete, simply remove the test cluster manifest.

______________________________________________________________________

## Helpful Inspection & Troubleshooting Commands

```bash
# Check status of all CNPG clusters
kubectl get clusters.postgresql.cnpg.io -A

# Detailed cluster overview with cnpg plugin
kubectl cnpg status <cluster-name> -n <namespace>

# List available backups recognized by the operator
kubectl get backups.postgresql.cnpg.io -n <namespace>

# Check ObjectStore status
kubectl get objectstores.barmancloud.cnpg.io -n <namespace>

# Check external secrets status for S3 credentials
kubectl get externalsecrets -n <namespace> s3-creds
```
