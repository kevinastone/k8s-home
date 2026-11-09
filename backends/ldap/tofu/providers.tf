terraform {
  required_version = ">= 1.10.0"
  required_providers {
    lldap = {
      source  = "tasansga/lldap"
      version = "0.5.0"
    }
    onepassword = {
      source  = "1Password/onepassword"
      version = "3.4.1"
    }
  }
}

# Provider connects via OP_CONNECT_HOST and OP_CONNECT_TOKEN environment variables
provider "onepassword" {}

provider "lldap" {
  http_url = var.lldap_http_url
  ldap_url = var.lldap_ldap_url
  username = var.LLDAP_LDAP_USER_DN
  password = var.LLDAP_LDAP_USER_PASS
  base_dn  = var.LLDAP_LDAP_BASE_DN
}
