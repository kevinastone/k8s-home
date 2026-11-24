resource "keycloak_openid_client" "client" {
  realm_id  = var.realm
  client_id = var.client_id
  name      = var.client_name
  enabled   = true

  access_type                  = "CONFIDENTIAL"
  client_secret                = var.OIDC_CLIENT_SECRET
  standard_flow_enabled        = true
  direct_access_grants_enabled = false
  consent_required             = false
  full_scope_allowed           = false
  pkce_code_challenge_method   = "S256"

  valid_redirect_uris = var.redirect_uris
  web_origins         = var.web_origins
}

resource "keycloak_openid_client_default_scopes" "client" {
  realm_id  = var.realm
  client_id = keycloak_openid_client.client.id

  default_scopes = [
    "basic",
    "profile",
    "email",
    "web-origins",
    "groups",
  ]
}
