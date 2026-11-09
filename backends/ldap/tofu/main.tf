data "onepassword_vault" "homelab" {
  name = var.onepassword_vault
}

# Fetch each user item directly by title using the Connect API
data "onepassword_item" "users" {
  for_each = var.ldap_users

  vault = data.onepassword_vault.homelab.uuid
  title = each.value.onepassword_item
}

resource "lldap_group" "groups" {
  for_each     = var.ldap_groups
  display_name = each.key
}

resource "lldap_user" "users" {
  for_each = var.ldap_users

  username            = data.onepassword_item.users[each.key].username
  password_wo         = data.onepassword_item.users[each.key].password
  password_wo_version = data.onepassword_item.users[each.key].updated_at
  # Utilizing v3+ section_map / field_map syntax
  email        = try(data.onepassword_item.users[each.key].section_map["ldap"].field_map["email"].value, "${data.onepassword_item.users[each.key].username}@k8s.kevinastone.com")
  display_name = try(data.onepassword_item.users[each.key].section_map["ldap"].field_map["display_name"].value, data.onepassword_item.users[each.key].title)
  first_name   = try(data.onepassword_item.users[each.key].section_map["ldap"].field_map["first_name"].value, null)
  last_name    = try(data.onepassword_item.users[each.key].section_map["ldap"].field_map["last_name"].value, null)
}

# Read built-in LLDAP admin group (ID 1)
data "lldap_group" "lldap_admin" {
  id = 1
}

locals {
  # Combined map of group display name -> group id
  all_groups = merge(
    { for k, v in lldap_group.groups : k => v.id },
    { (data.lldap_group.lldap_admin.display_name) = data.lldap_group.lldap_admin.id }
  )
}

resource "lldap_user_memberships" "memberships" {
  for_each = {
    for k, v in var.ldap_users : k => v
    if length(v.groups) > 0
  }

  user_id = lldap_user.users[each.key].id
  group_ids = toset([
    for g in each.value.groups :
    tostring(local.all_groups[trimspace(g)])
    if contains(keys(local.all_groups), trimspace(g))
  ])
}
