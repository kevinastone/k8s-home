terraform {
  required_version = ">= 1.10.0"
  required_providers {
    keycloak = {
      source  = "keycloak/keycloak"
      version = "5.11.0"
    }
  }
}

provider "keycloak" {
  url           = var.keycloak_url
  realm         = var.realm
  client_id     = var.OIDC_PROVISIONER_CLIENT_ID
  client_secret = var.OIDC_PROVISIONER_CLIENT_SECRET
}
