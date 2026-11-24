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
  url       = var.keycloak_url
  client_id = "admin-cli"
  username  = var.KC_BOOTSTRAP_ADMIN_USERNAME
  password  = var.KC_BOOTSTRAP_ADMIN_PASSWORD
}
