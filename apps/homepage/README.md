# Homepage Architecture & Cross-Namespace Secret Aggregation

This directory deploys [Homepage](https://gethomepage.dev/) (`ghcr.io/gethomepage/homepage`), providing a single dashboard for cluster applications, metrics, and services.

Homepage discovers services dynamically by watching Kubernetes `HTTPRoute` and `Ingress` resources across all namespaces using cluster-level RBAC (`rbac.yaml`).

## Cross-Namespace Secret Aggregation

Homepage service widgets (e.g., Radarr, Sonarr, SABnzbd) require API keys to fetch live status, queue progress, and statistics. Rather than duplicating API credentials or manually copying secrets into the `homepage` namespace, secrets are dynamically aggregated from remote application namespaces using [External Secrets Operator (ESO)](https://external-secrets.io/).

### How It Works

```
┌────────────────────────────────────────────────────────┐
│ App Namespace (e.g. `media`)                           │
│                                                        │
│ ExternalSecret (radarr, sonarr, sabnzbd)               │
│   ├── labels: { homepage.dev/secret: "true" }          │
│   └── data: { HOMEPAGE_VAR_RADARR_API_KEY: "..." }     │
└───────────────────────────┬────────────────────────────┘
                            │
                            │ Kubernetes Secret Store Provider
                            ▼
┌────────────────────────────────────────────────────────┐
│ `homepage` Namespace                                   │
│                                                        │
│ 1. ClusterSecretStore (`kubernetes-store.yaml`)        │
│    └── Points to remote namespace (e.g., `media`)      │
│                                                        │
│ 2. ExternalSecret (`external-secret.yaml`)             │
│    ├── Finds secrets with: homepage.dev/secret: "true" │
│    ├── merge.strategy: Extract                         │
│    └── target.creationPolicy: Merge                    │
│                                                        │
│ 3. Baseline Secret (`secret.yaml`)                     │
│    └── Secret/homepage-secrets (anchors lifecycle)     │
│                                                        │
│ 4. Target Secret (`Secret/homepage-secrets`)           │
│    ├── HOMEPAGE_VAR_RADARR_API_KEY                     │
│    ├── HOMEPAGE_VAR_SONARR_API_KEY                     │
│    └── HOMEPAGE_VAR_SABNZBD_API_KEY                    │
│                                                        │
│ 5. Homepage Pod (`helmrelease.yaml`)                   │
│    └── envFrom: [{ secretRef: homepage-secrets }]      │
│                                                        │
│ 6. HTTPRoute Annotation Interpolation                  │
│    └── gethomepage.dev/widget.key:                     │
│        "{{HOMEPAGE_VAR_RADARR_API_KEY}}"               │
└────────────────────────────────────────────────────────┘
```

### Components

1. **Remote Secret Tagging (`homepage.dev/secret: "true"`)**:
   Any application secret intended for Homepage labels its generated Secret with `homepage.dev/secret: "true"`, and formats the environment variable key using Homepage's variable prefix (e.g., `HOMEPAGE_VAR_<SERVICE>_API_KEY`).
   *Example from [`apps/media/radarr/external-secret.yaml`](../media/radarr/external-secret.yaml):*

   ```yaml
   template:
     metadata:
       labels:
         homepage.dev/secret: "true"
     data:
       HOMEPAGE_VAR_RADARR_API_KEY: "{{ .password }}"
   ```

1. **Cross-Namespace Secret Store (`kubernetes-store.yaml`)**:
   A `ClusterSecretStore` configured with the `kubernetes` provider points to the target remote namespace (e.g., `remoteNamespace: media`) and authenticates via ESO's in-cluster `external-secrets` ServiceAccount.

1. **ExternalSecret Aggregation (`external-secret.yaml`)**:
   Homepage's `ExternalSecret` queries the store via `dataFrom[].find.tags` for `homepage.dev/secret: "true"`. It uses `rewrite[].merge.strategy: Extract` and `conflictPolicy: Ignore` to unpack all matching keys.

1. **Lifecycle Anchor & Merge Policy (`secret.yaml`)**:
   [`secret.yaml`](./secret.yaml) defines an empty baseline `Secret/homepage-secrets`. Homepage's `ExternalSecret` targets this secret with `creationPolicy: Merge`. This allows multiple distinct secret stores (e.g. `media-kubernetes-store`, or future stores for other namespaces) to merge their keys into `homepage-secrets` without conflicts or lifecycle ownership battles.

1. **Injection into Homepage (`helmrelease.yaml`)**:
   The Homepage deployment injects all keys from `homepage-secrets` into the container environment via `envFrom`:

   ```yaml
   envFrom:
   - secretRef:
       name: homepage-secrets
   ```

1. **Runtime Widget Resolution**:
   When Homepage discovers an `HTTPRoute` annotated with widgets, Homepage substitutes `{{HOMEPAGE_VAR_<NAME>}}` placeholders with values from its environment.
   *Example from [`apps/media/radarr/http-route.yaml`](../media/radarr/http-route.yaml):*

   ```yaml
   metadata:
     annotations:
       gethomepage.dev/widget.type: radarr
       gethomepage.dev/widget.url: http://radarr.media.svc:7878
       gethomepage.dev/widget.key: "{{HOMEPAGE_VAR_RADARR_API_KEY}}"
   ```

## Adding Secrets from a New Namespace

To expose secrets from a new namespace (e.g., `monitoring` or `home-assistant`) to Homepage:

1. **Tag the Secret in the source namespace**:
   Ensure the source `ExternalSecret` adds `homepage.dev/secret: "true"` to `template.metadata.labels` and exposes the key as `HOMEPAGE_VAR_<NAME>`.

1. **Add a `ClusterSecretStore` for the namespace** (if one does not already exist):
   Create a store in [`apps/homepage/`](./) pointing to `remoteNamespace: <namespace>`:

   ```yaml
   apiVersion: external-secrets.io/v1
   kind: ClusterSecretStore
   metadata:
     name: <namespace>-kubernetes-store
   spec:
     provider:
       kubernetes:
         remoteNamespace: <namespace>
         server:
           url: https://kubernetes.default.svc
           caProvider:
             type: ConfigMap
             name: kube-root-ca.crt
             key: ca.crt
             namespace: kube-system
         auth:
           serviceAccount:
             name: external-secrets
             namespace: external-secrets
   ```

1. **Add an `ExternalSecret` targeting `homepage-secrets`**:
   Use `creationPolicy: Merge` targeting `homepage-secrets` so ESO merges keys into the existing secret without overwriting keys from other stores.
