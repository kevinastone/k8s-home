# Kopiur PVC Backup & Restore Runbook

This directory contains the shared Kustomize `Component` for backing up stateful PVCs to the NAS SMB share (`//storage.home.kevinastone.com/NAS/kopiur`) via [Kopiur](https://github.com/home-operations/kopiur).

______________________________________________________________________

## Architecture Overview

- **Operator & CRDs:** Deployed in `crds/kopiur/` (`kopiur-system` namespace) alongside `crds/snapshot-controller/` and the default Longhorn `VolumeSnapshotClass` (`longhorn-snapshot-vsc` in `system/longhorn/`).
- **Repository:** `ClusterRepository/nas-smb` (`system/kopiur/`) backed by the `storage-kopiur` SMB `StorageClass` (`subDir: "kopiur"`, `reclaimPolicy: Retain`) and encrypted with `KOPIA_PASSWORD` from 1Password (`ExternalSecret/kopiur-repository-secret`).
- **Component Resources (`components/kopiur/`):**
  - `pvc.yaml`: Provisions `kopiur-repo` (`ReadWriteMany`, `storageClassName: storage-kopiur`) in the consuming namespace so mover Jobs can mount the shared repository.
  - `snapshot-policy.yaml`: `SnapshotPolicy/kopiur-backup` selecting PVCs labeled `kopiur.home-operations.com/backup: "true"` in the namespace (`sourcePathStrategy: PvcNamespacedName`, `credentialProjection.enabled: true`, `mover.securityContext.runAsUser: 0`), with weekly `quick` verification (`H 4 * * 0`, `verifyFilesPercent: 5`).
  - `snapshot-schedule.yaml`: `SnapshotSchedule/kopiur-daily` running daily at `H 2 * * *` (`America/Los_Angeles`, `concurrencyPolicy: Forbid`).
  - `kustomization.yaml`: Patches the consuming `Namespace` with `kopiur.home-operations.com/privileged-movers: "true"` so movers can read `0600` app files (e.g. Home Assistant `.storage/*`).

### Enabling Backups on a Workload

1. Add `../../components/kopiur` to `components:` in the workload's `kustomization.yaml`.
1. Add the label `kopiur.home-operations.com/backup: "true"` to the PVC (or Helm `persistence` / `volumeClaimTemplate`).
1. *(Optional)* Override `spec.retention` with a Kustomize JSON patch (see `monitoring/victoria-metrics/kustomization.yaml`).

______________________________________________________________________

## Manual Snapshot Trigger

If you have the `kubectl-kopiur` plugin installed:

```bash
kubectl kopiur snapshot now --policy kopiur-backup -n <namespace>
```

Without the plugin, create a `Snapshot` CR specifying `spec.source` (required because `kopiur-backup` uses `pvcSelector`):

```bash
kubectl apply -f - <<'EOF'
apiVersion: kopiur.home-operations.com/v1alpha1
kind: Snapshot
metadata:
  name: manual-backup-20261112
  namespace: <namespace>
spec:
  policyRef:
    name: kopiur-backup
  source:
    sourceIndex: 0
    target:
      pvc:
        name: <pvc-name>
        namespace: <namespace>
EOF
```

______________________________________________________________________

## Restore Runbook

### Scenario 1: Non-Destructive Restore to a New PVC (Test / File Extraction)

Use `target.pvc` to have Kopiur create a brand-new PVC populated from a `Snapshot` CR without touching the live workload:

```bash
# List available Snapshot CRs in the namespace
kubectl get snapshot.kopiur.home-operations.com -n <namespace>

kubectl apply -f - <<'EOF'
apiVersion: kopiur.home-operations.com/v1alpha1
kind: Restore
metadata:
  name: test-restore
  namespace: <namespace>
spec:
  credentialProjection:
    enabled: true
  mover:
    securityContext:
      runAsNonRoot: false
      runAsUser: 0
  source:
    snapshotRef:
      name: <snapshot-name>
  target:
    pvc:
      name: <new-pvc-name>
      capacity: <size> # e.g. 1Gi, 10Gi
      storageClassName: longhorn
EOF

# Monitor restore progress
kubectl get restore -n <namespace> -w
```

Once complete, mount `<new-pvc-name>` in a temporary pod to inspect/copy files, then delete the `Restore` CR and scratch PVC when finished.

### Scenario 2: In-Place Restore to an Existing PVC

1. **Scale down the workload** (or suspend its `HelmRelease` via Flux) so nothing holds the PVC open or writes to it during restore.

1. **Apply a `Restore` CR** using `target.pvcRef`:

   ```bash
   kubectl apply -f - <<'EOF'
   apiVersion: kopiur.home-operations.com/v1alpha1
   kind: Restore
   metadata:
     name: restore-in-place
     namespace: <namespace>
   spec:
     credentialProjection:
       enabled: true
     mover:
       securityContext:
         runAsNonRoot: false
         runAsUser: 0
     source:
       snapshotRef:
         name: <snapshot-name>
     target:
       pvcRef:
         name: <existing-pvc-name>
   EOF
   ```

   *(If `Snapshot` CRs were pruned or you are restoring on a rebuilt cluster, use `source.fromPolicy` or `source.identity` with `spec.repository: { kind: ClusterRepository, name: nas-smb }` instead of `source.snapshotRef`.)*

1. **Verify & resume:** Wait for `kubectl get restore -n <namespace>` to report `Succeeded`, delete the `Restore` CR, and resume/scale the workload back up.
