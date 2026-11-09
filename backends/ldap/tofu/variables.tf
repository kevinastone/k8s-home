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
}

variable "ldap_users" {
  type = map(object({
    onepassword_item = string
    groups           = optional(list(string), [])
  }))
  description = "Map of LDAP users with their 1Password item title and group assignments"
}
