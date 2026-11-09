ldap_groups = [
  "media",
]

ldap_users = {
  "kstone" = {
    onepassword_item = "Home LDAP"
    groups           = ["media", "lldap_admin"]
  }
}
