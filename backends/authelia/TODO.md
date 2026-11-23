# Authelia & Envoy Gateway Auth Improvement Recommendations

This document tracks improvements to OIDC client management, secret distribution, and per-application authorization across [`backends/authelia/`](./kustomization.yaml) and [`backends/envoy-gateway/security-policy.yaml`](../envoy-gateway/security-policy.yaml).

______________________________________________________________________

## 1. OIDC Client Secret Management & Config Cleanup

- [x] **Consolidate OIDC Client Secrets into a Single Manifest & Use File-Mounted Template Secrets**:
  - [x] Consolidate per-app secret manifests ([`grafana-client-secret.yaml`](./grafana-client-secret.yaml), [`rustfs-client-secret.yaml`](./rustfs-client-secret.yaml)) into [`oidc-clients.yaml`](./oidc-clients.yaml) (keeping one `ExternalSecret` per client with `refreshPolicy: OnChange` so adding a new client never rotates existing clients' secrets).
  - [x] Mount OIDC client secrets via a `projected` volume at `/secrets/oidc` in [`helmrelease.yaml`](./helmrelease.yaml) and remove the per-client `envFrom` entries so consuming-app env vars are not leaked into the Authelia container.
  - [x] Switch `X_AUTHELIA_CONFIG_FILTERS` in [`helmrelease.yaml`](./helmrelease.yaml) from `expand-env` to `template`, reading client secrets from files via `{{ secret "/secrets/oidc/<client>" }}` (matching the existing `*_FILE` pattern).
- [x] **Decouple App-Specific Env Var Names**:
  - [x] Move app-specific key remapping (`GF_AUTH_GENERIC_OAUTH_CLIENT_SECRET`, `RUSTFS_IDENTITY_OPENID_CLIENT_SECRET`) into each consuming app's `ExternalSecret` ([`monitoring/grafana/authelia-client-secret.yaml`](../../monitoring/grafana/authelia-client-secret.yaml), [`backends/rustfs/authelia-client-secret.yaml`](../rustfs/authelia-client-secret.yaml)) using `remoteRef: { key: <client>-client-secret, property: client_secret }`.
- [x] **Restrict `authelia-kubernetes-store` Blast Radius**:
  - [x] Added `spec.conditions.namespaces` (`grafana`, `rustfs`) to [`kubernetes-store.yaml`](./kubernetes-store.yaml) so only OIDC consumer namespaces can use `authelia-kubernetes-store`. *(Note: ESO's Kubernetes provider `Validate()` requires `list` on secrets in `remoteNamespace`, so further per-secret scoping would require moving OIDC client secrets to a dedicated namespace if needed later.)*
- [x] **Hash OIDC Client Secrets for Authelia**:
  - [x] Generate a bcrypt hash (`client_secret_hash` via Sprig `htpasswd`) alongside `client_secret` in [`oidc-clients.yaml`](./oidc-clients.yaml) and mount `client_secret_hash` into Authelia at `/secrets/oidc/<client>` while consuming apps continue pulling plaintext `client_secret`.
- [x] **Deduplicate & Clean Up [`resources/configuration.yaml`](./resources/configuration.yaml)**:
  - [x] Reuse shared OIDC client scopes via YAML anchor (`&oidc_scopes`), drop redundant built-in defaults (`public: false`, `userinfo_signed_response_alg: none`), and migrate legacy `id`/`description`/`secret` keys to `client_id`/`client_name`/`client_secret`.
  - [x] Remove redundant `pre_configured_consent_duration: 1y` from clients using `consent_mode: implicit` (it only applies to `explicit` consent mode).
  - [x] Update `totp.issuer` from `authelia.com` to `k8s.kevinastone.com`.
- [ ] *(Optional — if OIDC client count grows significantly)* **Evaluate API-Driven IdP for Co-Located Per-App OIDC**:
  - [ ] Authelia is file-configured only (no API, CRD, or OpenTofu provider). If many more OIDC apps are added and co-located per-app provisioning (similar to [`components/rustfs-bucket/`](../../components/rustfs-bucket/kustomization.yaml)) becomes desirable, evaluate an IdP with an OpenTofu provider (e.g., Pocket ID, Authentik, or Keycloak).

______________________________________________________________________

## 2. Migrate Envoy Gateway `auth-gateway` from `extAuth` to OIDC + JWT

Replace per-request `extAuth` calls to Authelia on `auth-gateway` with Envoy Gateway's native `oidc` + `jwt` filters so Envoy verifies JWTs locally via Authelia's JWKS and supports co-located per-`HTTPRoute` group RBAC via `SecurityPolicy` (`mergeType: StrategicMerge` + `principal.jwt.claims`).

- [ ] **Register an `envoy-gateway` OIDC Client in Authelia**:
  - [ ] Add an `envoy-gateway-client-secret` `ExternalSecret` to [`oidc-clients.yaml`](./oidc-clients.yaml) and mount its `client_secret_hash` into `/secrets/oidc/envoy-gateway` in [`helmrelease.yaml`](./helmrelease.yaml).
  - [ ] Allow the `envoy` namespace in [`kubernetes-store.yaml`](./kubernetes-store.yaml) (`spec.conditions.namespaces`) and add an `ExternalSecret` in `backends/envoy-gateway/` pulling `client_secret` into the `client-secret` key expected by `SecurityPolicy.spec.oidc.clientSecret`.
  - [ ] Add an `identity_providers.oidc.claims_policies` entry in [`resources/configuration.yaml`](./resources/configuration.yaml) including `id_token: [groups, email, preferred_username, name]` (Authelia omits `groups` from the ID token by default) and attach it to the `envoy-gateway` client.
  - [ ] Register a single fixed `redirect_uri` (`https://envoy.k8s.kevinastone.com/oauth2/callback`) on the `envoy-gateway` client in [`resources/configuration.yaml`](./resources/configuration.yaml).
- [ ] **Create Dedicated OAuth Callback `HTTPRoute` on `auth-gateway`**:
  - [ ] Add a small `HTTPRoute` in `backends/envoy-gateway/` for `envoy.k8s.kevinastone.com` attached to `auth-gateway` so ExternalDNS publishes the record and Envoy's built-in `oauth2` filter intercepts `/oauth2/callback` in-process (after exchanging the code and setting cookies on `cookieDomain: k8s.kevinastone.com`, Envoy redirects back to the original `*.k8s.kevinastone.com` URL stored in OIDC `state`).
- [ ] **Switch `auth-gateway-policy` to `oidc` + `jwt`**:
  - [ ] Replace `extAuth` in [`backends/envoy-gateway/security-policy.yaml`](../envoy-gateway/security-policy.yaml) with `oidc` (`cookieDomain: k8s.kevinastone.com`, `redirectURL: https://envoy.k8s.kevinastone.com/oauth2/callback`, `scopes: [openid, profile, email, groups]`) and `jwt` (validating the ID token against `https://auth.k8s.kevinastone.com/jwks.json`, with optional `claimToHeaders` for `Remote-User`/`Remote-Groups`).
  - [ ] Clean up unused `ext-authz` config ([`reference-grant.yaml`](./reference-grant.yaml) and `server.endpoints.authz.ext-authz` in [`resources/configuration.yaml`](./resources/configuration.yaml)) once verified.

______________________________________________________________________

## 3. Per-Application Permissioning (Co-Located `SecurityPolicy` & OIDC Authorization Policies)

> **Revisit after Section 2:** Once `auth-gateway` uses `oidc` + `jwt`, each app can co-locate a lightweight `SecurityPolicy` (`mergeType: StrategicMerge`) right next to its `http-route.yaml` using `authorization.rules[].principal.jwt.claims` on the `groups` `StringArray` claim (without duplicating OIDC/JWT config or needing per-namespace `ReferenceGrant`s). Set `authorization: { defaultAction: Deny }` on `auth-gateway-policy` so new routes fail closed. *(Note: if per-app 2FA step-up is ever needed, keep or fall back to Authelia `access_control.rules` instead.)*

- [ ] **Add Co-Located Per-Route `SecurityPolicy` Group Rules (or Authelia `access_control` Rules)**:
  - [ ] Enable `authorization: { defaultAction: Deny }` on `auth-gateway-policy` in [`backends/envoy-gateway/security-policy.yaml`](../envoy-gateway/security-policy.yaml) and attach `mergeType: StrategicMerge` `SecurityPolicy` manifests alongside each app's `http-route.yaml`:
    - Admin/infrastructure apps (`longhorn`, `goldilocks`, `clickhouse`, `argo`, `zigbee2mqtt`, `unifi`, etc.) → `groups` contains `lldap_admin`.
    - Media apps (`sonarr`, `radarr`, `prowlarr`, `sabnzbd`, `qbittorrent`) → `groups` contains `media` or `lldap_admin`.
    - Shared/general apps (`home`, `sudoku`, `2048`) → any authenticated user.
- [ ] **Add OIDC `authorization_policies` & Fix Over-Permissive App Role Mappings**:
  - [ ] Define named policies under `identity_providers.oidc.authorization_policies` (e.g., `admin_only` requiring `group:lldap_admin` with `default_policy: deny`) in [`resources/configuration.yaml`](./resources/configuration.yaml) and assign them to `rustfs` and `grafana`.
  - [ ] In [`monitoring/grafana/helmrelease.yaml`](../../monitoring/grafana/helmrelease.yaml), replace `role_attribute_path: "'Admin'"` with group-based mapping (`contains(groups[*], 'lldap_admin') && 'Admin' || 'Viewer'`) directly under `auth.generic_oauth` (and remove the invalid commented `auth.generic_oauth.group_mapping` section).
  - [ ] In [`backends/rustfs/helmrelease.yaml`](../rustfs/helmrelease.yaml), verify `RUSTFS_IDENTITY_OPENID_ROLE_POLICY: consoleAdmin` is gated by Authelia's `admin_only` OIDC authorization policy (or switch to claim-based policy mapping with `groups` scope).
