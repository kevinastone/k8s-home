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
  default     = ["media"]
}

variable "ldap_user_items" {
  type        = list(string)
  description = "Explicit list of 1Password item titles representing LDAP users"
  default     = ["Home LDAP"]
}
