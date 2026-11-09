# LLDAP OpenTofu Configuration Plan (`TODO.md`)

This document provides a step-by-step implementation plan to manage LLDAP users, groups, and group memberships declaratively via `tofu-controller` (`infra.contrib.fluxcd.io/v1alpha2`), backed by user accounts stored in the `Homelab` vault in 1Password Connect.

______________________________________________________________________

## 1. Architectural Context & Repository Conventions

Before implementing, note how this repository differs from the generic example snippet:

- **Namespace & Directory Layout**:
  - LLDAP is deployed in the `ldap` namespace via [`backends/ldap/kustomization.yaml`](./kustomization.yaml).
  - OpenTofu modules managed by `tofu-controller` live in a `tofu/` subdirectory alongside a `terraform.yaml` manifest in the application directory (matching [`backends/rustfs/terraform.yaml`](../rustfs/terraform.yaml), [`apps/media/sonarr/terraform.yaml`](../../apps/media/sonarr/terraform.yaml), [`apps/media/radarr/terraform.yaml`](../../apps/media/radarr/terraform.yaml), and [`apps/media/prowlarr/terraform.yaml`](../../apps/media/prowlarr/terraform.yaml)).
- **Flux GitRepository Source**:
  - The cluster's `GitRepository` is named `fluxcd-sync` in namespace `flux-system` (not `flux-system`).
- **LLDAP Service & Base DN**:
  - In [`backends/ldap/helmrelease.yaml`](./helmrelease.yaml), the `lldap` `Service` exposes port `80` (targeting container port `17170` for HTTP) and port `389` (targeting container port `3890` for LDAP).
  - Within the `ldap` namespace, the service endpoints are:
    - HTTP URL: `http://lldap.ldap.svc.cluster.local:80` (or `http://lldap:80`)
    - LDAP URL: `ldap://lldap.ldap.svc.cluster.local:389` (or `ldap://lldap:389`)
  - In [`backends/ldap/lldap-secret.yaml`](./lldap-secret.yaml) and [`backends/authelia/resources/configuration.yaml`](../authelia/resources/configuration.yaml), the Base DN is `dc=home,dc=kevinastone,dc=com` and the admin user is `admin`.
- **LLDAP Admin Credentials**:
  - The 1Password item in the `Homelab` vault is titled `LLDAP` (extracted in [`backends/ldap/lldap-secret.yaml`](./lldap-secret.yaml) and [`backends/authelia/ldap-secret.yaml`](../authelia/ldap-secret.yaml)).
  - Alternatively, because [`lldap-secret`](./lldap-secret.yaml) already exists in the `ldap` namespace with `LLDAP_LDAP_USER_DN` (`admin`) and `LLDAP_LDAP_USER_PASS`, those credentials can either be read via `data "onepassword_item" "lldap_admin"` (`title = "LLDAP"`) or injected directly from `lldap-secret` via `varsFrom`.
- **1Password Connect Endpoint & Authentication**:
  - 1Password Connect runs in the `one-password` namespace ([`backends/one-password/helmrelease.yaml`](../one-password/helmrelease.yaml) and [`backends/one-password/cluster-secret-store.yaml`](../one-password/cluster-secret-store.yaml)).
  - Connect API URL: `http://onepassword-connect.one-password.svc.cluster.local:8438`
  - Vault name: `Homelab`
  - **Note on `op` CLI vs. Connect API**: When `OP_CONNECT_HOST` and `OP_CONNECT_TOKEN` (or provider `url` and `token`) are provided to `1Password/onepassword`, the provider uses the 1Password Connect REST client directly over HTTP and **does not** invoke the `op` CLI binary. However, if the `runnerPodTemplate` initContainer pattern from the example is used, note that `tofu-controller` mounts custom volumes or env vars on the runner pod. Even simpler and cleaner in this repo is passing the Connect token via a local `Secret` / `ExternalSecret` or `runnerPodTemplate` env var (see Step 2).

______________________________________________________________________

## 2. Provisioning the 1Password Connect Token in `ldap` Namespace

The `tofu-controller` runner pod executes in the `ldap` namespace (where the `Terraform` resource lives) and needs `OP_CONNECT_TOKEN` to authenticate with `http://onepassword-connect.one-password.svc.cluster.local:8438`.

In [`backends/one-password/kustomization.yaml`](../one-password/kustomization.yaml), `one-password-secret` is generated with a hash suffix by Kustomize (`secretGenerator`) in the `one-password` namespace. To make the Connect `token` available in the `ldap` namespace without hardcoding a Kustomize secret hash:

### Option A: Store/Expose the Connect Token via `ExternalSecret` or SOPS in `backends/ldap` (Recommended)

Check if the Connect token is stored in the `Homelab` 1Password vault (or add an `ExternalSecret` / SOPS-encrypted secret in `backends/ldap`):

1. If stored in 1Password (or if you prefer SOPS matching [`backends/one-password/secrets/token.encrypted`](../one-password/secrets/token.encrypted)), create a Secret in `ldap` (e.g., `onepassword-connect-token`) containing key `token`.
1. Alternatively, in [`backends/one-password/kustomization.yaml`](../one-password/kustomization.yaml), add `generatorOptions.disableNameSuffixHash: true` (or reflector annotations via [`system/reflector`](../../system/reflector/helmrelease.yaml)) on `one-password-secret` so `reflector` replicates `one-password-secret` to the `ldap` namespace:
   ```yaml
   # In backends/one-password/kustomization.yaml
   secretGenerator:
   - name: one-password-secret
     options:
       annotations:
         reflector.v1.k8s.emberstack.com/reflection-allowed: "true"
         reflector.v1.k8s.emberstack.com/reflection-allowed-namespaces: "ldap"
         reflector.v1.k8s.emberstack.com/reflection-auto-enabled: "true"
         reflector.v1.k8s.emberstack.com/reflection-auto-namespaces: "ldap"
   ```
   *(Verify with `kubectl get secret -n ldap` after inspecting the cluster to see if a secret or 1Password item already exists).*

______________________________________________________________________

## 3. Files to Create & Modify

### Step 3.1: Create `backends/ldap/terraform.yaml`

Create [`backends/ldap/terraform.yaml`](./terraform.yaml) following the exact RBAC and `Terraform` CRD conventions in [`backends/rustfs/terraform.yaml`](../rustfs/terraform.yaml) and [`apps/media/sonarr/terraform.yaml`](../../apps/media/sonarr/terraform.yaml):

```yaml
# yaml-language-server: $schema=https://k8s-schemas.home-operations.com/infra.contrib.fluxcd.io/terraform_v1alpha2.json
apiVersion: infra.contrib.fluxcd.io/v1alpha2
kind: Terraform
metadata:
  name: lldap
spec:
  serviceAccountName: tf-runner
  interval: 15m
  approvePlan: auto
  path: ./backends/ldap/tofu
  sourceRef:
    kind: GitRepository
    name: fluxcd-sync
    namespace: flux-system
  varsFrom:
  - kind: Secret
    name: lldap-secret
    varsKeys:
    - LLDAP_LDAP_USER_DN
    - LLDAP_LDAP_USER_PASS
    - LLDAP_LDAP_BASE_DN
  runnerPodTemplate:
    spec:
      env:
      - name: OP_CONNECT_HOST
        value: "http://onepassword-connect.one-password.svc.cluster.local:8438"
      - name: OP_CONNECT_TOKEN
        valueFrom:
          secretKeyRef:
            name: one-password-secret # Or onepassword-connect-token depending on Step 2
            key: token
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: tf-runner
---
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: tf-runner
rules:
- apiGroups: [""]
  resources: ["secrets"]
  verbs: ["*"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: tf-runner
subjects:
- kind: ServiceAccount
  name: tf-runner
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: tf-runner
```

> **Note on `install-op-cli` initContainer**: If `1Password/onepassword` v3+ requires the `op` binary on `PATH` during provider initialization in your runner image (`ghcr.io/home-operations/opentofu-runner`), include the `initContainers` / `volumes` / `volumeMounts` stanza from the reference example and set `OP_CLI_PATH: /custom-tools/op` in `runnerPodTemplate.spec.env`. Test without it first, as Connect mode (`OP_CONNECT_HOST` + `OP_CONNECT_TOKEN`) uses the REST API directly.

### Step 3.2: Create `backends/ldap/tofu/providers.tf`

Create [`backends/ldap/tofu/providers.tf`](./tofu/providers.tf):

```hcl
terraform {
  required_version = ">= 1.10.0"
  required_providers {
    lldap = {
      source  = "tasansga/lldap"
      version = "0.4.5"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.4.0"
    }
  }
}

# Connects via OP_CONNECT_HOST and OP_CONNECT_TOKEN environment variables
provider "onepassword" {}

provider "lldap" {
  http_url = var.lldap_http_url
  ldap_url = var.lldap_ldap_url
  username = var.LLDAP_LDAP_USER_DN
  password = var.LLDAP_LDAP_USER_PASS
  base_dn  = var.LLDAP_LDAP_BASE_DN
}
```

*(Note: Pin exact provider versions like `"0.4.5"` and `"3.4.0"` rather than `~>` so Renovate can track and bump them cleanly via the ` registry.opentofu.org` rule in [`.github/renovate.jsonc`](../../.github/renovate.jsonc)).*

### Step 3.3: Create `backends/ldap/tofu/variables.tf`

Create [`backends/ldap/tofu/variables.tf`](./tofu/variables.tf):

```hcl
variable "lldap_http_url" {
  type        = string
  description = "LLDAP HTTP URL"
  default     = "http://lldap.ldap.svc.cluster.local:80"
}

variable "lldap_ldap_url" {
  type        = string
  description = "LLDAP LDAP URL"
  default     = "ldap://lldap.ldap.svc.cluster.local:389"
}

variable "LLDAP_LDAP_BASE_DN" {
  type        = string
  description = "LLDAP Base DN"
  default     = "dc=home,dc=kevinastone,dc=com"
}

variable "LLDAP_LDAP_USER_DN" {
  type        = string
  description = "LLDAP Admin Username"
  default     = "admin"
}

variable "LLDAP_LDAP_USER_PASS" {
  type        = string
  description = "LLDAP Admin Password"
  sensitive   = true
}

variable "onepassword_vault" {
  type        = string
  description = "1Password Vault name containing user items"
  default     = "Homelab"
}

variable "ldap_groups" {
  type        = set(string)
  description = "Set of LLDAP group display names to manage"
  default     = ["admins", "family", "media"]
}

variable "ldap_user_items" {
  type        = list(string)
  description = "Explicit list of 1Password item titles (or UUIDs) representing LDAP users"
  default     = [
    # Populate with actual 1Password item titles from the Homelab vault
  ]
}
```

### Step 3.4: Create `backends/ldap/tofu/main.tf`

Create [`backends/ldap/tofu/main.tf`](./tofu/main.tf) to query the `Homelab` vault, fetch the explicitly listed user items, create groups and users, and optionally wire group memberships:

```hcl
data "onepassword_vault" "homelab" {
  name = var.onepassword_vault
}

# Fetch each user item directly by title using the Connect API
data "onepassword_item" "users" {
  for_each = toset(var.ldap_user_items)

  vault = data.onepassword_vault.homelab.uuid
  title = each.key
}

resource "lldap_group" "groups" {
  for_each     = var.ldap_groups
  display_name = each.key
}

resource "lldap_user" "users" {
  for_each = data.onepassword_item.users

  username     = each.value.username
  password     = each.value.password
  email        = try(each.value.section_map["ldap"].field_map["email"].value, "${each.value.username}@kevinastone.com")
  display_name = try(each.value.section_map["ldap"].field_map["display_name"].value, each.value.title)
  first_name   = try(each.value.section_map["ldap"].field_map["first_name"].value, null)
  last_name    = try(each.value.section_map["ldap"].field_map["last_name"].value, null)
}

# Optional: Manage group memberships per user via a comma-separated `groups` custom field
# in the 1Password `ldap` section (e.g. "admins,media"), or via a static Terraform map:
resource "lldap_user_memberships" "memberships" {
  for_each = {
    for k, v in data.onepassword_item.users : k => v
    if can(v.section_map["ldap"].field_map["groups"].value)
  }

  user_id = lldap_user.users[each.key].id
  group_ids = toset([
    for g in split(",", each.value.section_map["ldap"].field_map["groups"].value) :
    lldap_group.groups[trimspace(g)].id
    if contains(keys(lldap_group.groups), trimspace(g))
  ])
}
```

### Step 3.5: Register `terraform.yaml` in `backends/ldap/kustomization.yaml`

Update [`backends/ldap/kustomization.yaml`](./kustomization.yaml) to include `terraform.yaml`:

```yaml
# yaml-language-server: $schema=https://json.schemastore.org/kustomization
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: ldap
resources:
- namespace.yaml
- helmrelease.yaml
- http-route.yaml
- lldap-secret.yaml
- postgres
- terraform.yaml
```

______________________________________________________________________

## 4. Pre-Implementation Discovery Checklist (For Implementing Agent)

When executing this plan, the implementing agent should first inspect the live cluster (read-only) or ask the user to confirm:

1. **Existing LLDAP Users & Groups**:
   - Inspect existing users/groups in LLDAP (or ask the user if existing manually-created users/groups in LLDAP should be recreated or imported into state, or if LLDAP can take over cleanly).
   - Check [`monitoring/grafana/helmrelease.yaml`](../../monitoring/grafana/helmrelease.yaml) and [`backends/authelia/resources/configuration.yaml`](../authelia/resources/configuration.yaml) for any group names expected by downstream OIDC apps (note: LLDAP has built-in `lldap_admin`, `lldap_password_manager`, and `lldap_strict_readonly` groups which should not be recreated as custom `lldap_group` resources unless imported).
1. **1Password Item Titles & Schema**:
   - Confirm the exact 1Password item titles (or UUIDs) in the `Homelab` vault to list in `ldap_user_items` (or define a map variable in `variables.tf` with each user's 1Password item title and desired groups).
   - Confirm whether email/display_name/groups are stored in a custom `ldap` section on the 1Password Login items or in standard fields, or if group memberships should be declared directly in Terraform (e.g., `variable "ldap_users"` as a `map(object({ item_title = string, groups = list(string) }))`).
1. **1Password Connect Token Secret**:
   - Check `kubectl get secrets -n one-password` to verify the generated name of `one-password-secret` and configure `reflector` annotations in [`backends/one-password/kustomization.yaml`](../one-password/kustomization.yaml) so `one-password-secret` is reflected into the `ldap` namespace.

______________________________________________________________________

## 5. Validation & Formatting

After creating/modifying the files:

1. **Format all files using Nix**:
   ```bash
   nix fmt
   ```
1. **Validate Kustomize build**:
   ```bash
   kustomize build backends/ldap
   ```
1. **Run Flake Checks**:
   ```bash
   nix flake check -L
   ```
1. **Follow GitOps Rules**:
   - Do **not** run `kubectl apply` or `git push` without explicit user approval.
