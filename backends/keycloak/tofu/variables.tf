variable "keycloak_url" {
  type        = string
  description = "Internal Keycloak HTTP URL"
  default     = "http://keycloak.keycloak.svc.cluster.local:8080"
}

variable "KC_BOOTSTRAP_ADMIN_USERNAME" {
  type        = string
  description = "Keycloak bootstrap admin username"
}

variable "KC_BOOTSTRAP_ADMIN_PASSWORD" {
  type        = string
  description = "Keycloak bootstrap admin password"
  sensitive   = true
}

variable "lldap_url" {
  type        = string
  description = "LLDAP LDAP URL"
  default     = "ldap://lldap.ldap.svc.cluster.local:389"
}

variable "lldap_base_dn" {
  type        = string
  description = "LLDAP Base DN"
  default     = "dc=home,dc=kevinastone,dc=com"
}

variable "LLDAP_BIND_PASSWORD" {
  type        = string
  description = "LLDAP admin bind password"
  sensitive   = true
}
