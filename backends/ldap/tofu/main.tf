data "onepassword_vault" "homelab" {
  name = var.onepassword_vault
}

# Fetch each user item directly by title using the Connect API
data "onepassword_item" "users" {
  for_each = toset(var.ldap_user_items)

  vault = data.onepassword_vault.homelab.uuid
  title = each.key
}

resource "lldap_group" "groups" {
  for_each     = var.ldap_groups
  display_name = each.key
}

resource "lldap_user" "users" {
  for_each = data.onepassword_item.users

  username            = each.value.username
  password_wo         = each.value.password
  password_wo_version = each.value.updated_at
  # Utilizing v3+ section_map / field_map syntax
  email        = try(each.value.section_map["ldap"].field_map["email"].value, "${each.value.username}@k8s.kevinastone.com")
  display_name = try(each.value.section_map["ldap"].field_map["display_name"].value, each.value.title)
  first_name   = try(each.value.section_map["ldap"].field_map["first_name"].value, null)
  last_name    = try(each.value.section_map["ldap"].field_map["last_name"].value, null)
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
    for k, v in data.onepassword_item.users : k => v
    if can(v.section_map["ldap"].field_map["groups"].value)
  }

  user_id = lldap_user.users[each.key].id
  group_ids = toset([
    for g in split(",", each.value.section_map["ldap"].field_map["groups"].value) :
    tostring(local.all_groups[trimspace(g)])
    if contains(keys(local.all_groups), trimspace(g))
  ])
}
