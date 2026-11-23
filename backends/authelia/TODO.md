# Authelia & Envoy Gateway Auth Improvement Recommendations

This document tracks improvements to OIDC client management, secret distribution, and per-application authorization across [`backends/authelia/`](./kustomization.yaml) and [`backends/envoy-gateway/security-policy.yaml`](../envoy-gateway/security-policy.yaml).

______________________________________________________________________

## 1. OIDC Client Secret Management & Config Cleanup

- [x] **Consolidate OIDC Client Secrets into a Single Manifest & Use File-Mounted Template Secrets**:
  - [x] Consolidate per-app secret manifests ([`grafana-client-secret.yaml`](./grafana-client-secret.yaml), [`rustfs-client-secret.yaml`](./rustfs-client-secret.yaml)) into [`oidc-clients.yaml`](./oidc-clients.yaml) (keeping one `ExternalSecret` per client with `refreshPolicy: OnChange` so adding a new client never rotates existing clients' secrets).
  - [x] Mount OIDC client secrets via a `projected` volume at `/secrets/oidc` in [`helmrelease.yaml`](./helmrelease.yaml) and remove the per-client `envFrom` entries so consuming-app env vars are not leaked into the Authelia container.
  - [x] Switch `X_AUTHELIA_CONFIG_FILTERS` in [`helmrelease.yaml`](./helmrelease.yaml) from `expand-env` to `template`, reading client secrets from files via `{{ secret "/secrets/oidc/<client>" }}` (matching the existing `*_FILE` pattern).
- [ ] **Decouple App-Specific Env Var Names**:
  - [ ] Move app-specific key remapping (`GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`, `RUSTFS_IDENTITY_OPENID_CLIENT_SECRET`) into each consuming app's `ExternalSecret` ([`monitoring/grafana/authelia-client-secret.yaml`](../../monitoring/grafana/authelia-client-secret.yaml), [`backends/rustfs/authelia-client-secret.yaml`](../rustfs/authelia-client-secret.yaml)) using `remoteRef: { key: oidc-client-secrets, property: <client> }`.
- [ ] **Restrict `authelia-kubernetes-store` Blast Radius**:
  - [ ] [`kubernetes-store.yaml`](./kubernetes-store.yaml) currently grants cross-namespace read access to *all* `Secret`s in the `authelia` namespace (including `authelia-secret`, `ldap-secret`, and `postgres-app`). Scope access down (via `ClusterSecretStore` conditions or dedicated RBAC) so consuming namespaces can only read `oidc-client-secrets`.
- [ ] **Evaluate Hashed OIDC Client Secrets**:
  - [ ] Authelia currently loads plaintext client secrets in [`resources/configuration.yaml`](./resources/configuration.yaml) (which triggers deprecation warnings). Evaluate hashing the Authelia-side secret (`$pbkdf2-sha512$` or `$argon2id$`) while keeping plaintext for the consuming app.
- [ ] **Deduplicate & Clean Up [`resources/configuration.yaml`](./resources/configuration.yaml)**:
  - [ ] Extract shared OIDC client defaults (`public: false`, `consent_mode: implicit`, `scopes`, `userinfo_signed_response_alg: none`) into a YAML anchor (`&default_oidc_client`).
  - [ ] Remove redundant `pre_configured_consent_duration: 1y` from clients using `consent_mode: implicit` (it only applies to `explicit` consent mode).
  - [ ] Update `totp.issuer` from `authelia.com` to a homelab-specific value (e.g., `k8s.kevinastone.com`).
- [ ] *(Optional — if OIDC client count grows significantly)* **Evaluate API-Driven IdP for Co-Located Per-App OIDC**:
  - [ ] Authelia is file-configured only (no API, CRD, or OpenTofu provider). If many more OIDC apps are added and co-located per-app provisioning (similar to [`components/rustfs-bucket/`](../../components/rustfs-bucket/kustomization.yaml)) becomes desirable, evaluate an IdP with an OpenTofu provider (e.g., Pocket ID, Authentik, or Keycloak).

______________________________________________________________________

## 2. Per-Application Permissioning (Authelia + Envoy Gateway)

> **Envoy Gateway Gotcha:** A `SecurityPolicy` attached to an `HTTPRoute` **overrides** (rather than merges with) a `SecurityPolicy` attached to the parent `Gateway`. Avoid creating per-app `SecurityPolicy` resources for RBAC — doing so would require duplicating `cors` and `extAuth` per route and expanding [`reference-grant.yaml`](./reference-grant.yaml) to every app namespace. Keep a single Gateway-level `auth-gateway-policy` and enforce per-app RBAC in Authelia using LLDAP groups ([`backends/ldap/tofu/terraform.tfvars`](../ldap/tofu/terraform.tfvars)).

- [ ] **Replace Wildcard `access_control` Rule with Per-App Group Rules**:
  - [ ] Replace the `*.k8s.kevinastone.com` catch-all in [`resources/configuration.yaml`](./resources/configuration.yaml) with explicit group-scoped rules so `default_policy: deny` fails closed for newly exposed apps:
    - Admin/infrastructure apps (`longhorn`, `goldilocks`, `clickhouse`, `argo`, `zigbee2mqtt`, `unifi`, etc.) → `subject: ["group:lldap_admin"]` (consider `policy: two_factor`).
    - Media apps (`sonarr`, `radarr`, `prowlarr`, `sabnzbd`, `qbittorrent`) → `subject: ["group:media", "group:lldap_admin"]`, `policy: one_factor`.
    - Shared/general apps (`home`, `sudoku`, `2048`) → `policy: one_factor`.
- [ ] **Add OIDC `authorization_policies` & Fix Over-Permissive App Role Mappings**:
  - [ ] Define named policies under `identity_providers.oidc.authorization_policies` (e.g., `admin_only` requiring `group:lldap_admin` with `default_policy: deny`) in [`resources/configuration.yaml`](./resources/configuration.yaml) and assign them to `rustfs` and `grafana`.
  - [ ] In [`monitoring/grafana/helmrelease.yaml`](../../monitoring/grafana/helmrelease.yaml), replace `role_attribute_path: "'Admin'"` with group-based mapping (`contains(groups[*], 'lldap_admin') && 'Admin' || 'Viewer'`) directly under `auth.generic_oauth` (and remove the invalid commented `auth.generic_oauth.group_mapping` section).
  - [ ] In [`backends/rustfs/helmrelease.yaml`](../rustfs/helmrelease.yaml), verify `RUSTFS_IDENTITY_OPENID_ROLE_POLICY: consoleAdmin` is gated by Authelia's `admin_only` OIDC authorization policy (or switch to claim-based policy mapping with `groups` scope).
- [ ] **Forward Identity Headers from Envoy Gateway to Backends**:
  - [ ] Add `headersToBackend` (`Remote-User`, `Remote-Groups`, `Remote-Name`, `Remote-Email`) under `extAuth.http` in [`backends/envoy-gateway/security-policy.yaml`](../envoy-gateway/security-policy.yaml) so upstream apps behind `auth-gateway` can consume authenticated user/group context if needed.
