resource "keycloak_realm" "homelab" {
  realm   = "homelab"
  enabled = true

  display_name = "Homelab"

  remember_me                          = true
  login_with_email_allowed             = true
  sso_session_idle_timeout             = "720h"
  sso_session_max_lifespan             = "8760h"
  sso_session_idle_timeout_remember_me = "720h"
  sso_session_max_lifespan_remember_me = "8760h"
  offline_session_idle_timeout         = "8760h"
  offline_session_max_lifespan_enabled = false
}

resource "keycloak_ldap_user_federation" "lldap" {
  name     = "lldap"
  realm_id = keycloak_realm.homelab.id
  enabled  = true

  connection_url  = var.lldap_url
  users_dn        = "ou=people,${var.lldap_base_dn}"
  bind_dn         = "uid=admin,ou=people,${var.lldap_base_dn}"
  bind_credential = var.LLDAP_BIND_PASSWORD

  username_ldap_attribute = "uid"
  rdn_ldap_attribute      = "uid"
  uuid_ldap_attribute     = "uid"
  user_object_classes = [
    "inetOrgPerson",
    "person",
    "top",
  ]

  search_scope = "ONE_LEVEL"
  trust_email  = true
  edit_mode    = "READ_ONLY"

  full_sync_period    = 3600
  changed_sync_period = 300
}

resource "keycloak_ldap_group_mapper" "lldap_groups" {
  realm_id                = keycloak_realm.homelab.id
  ldap_user_federation_id = keycloak_ldap_user_federation.lldap.id
  name                    = "lldap-groups"

  ldap_groups_dn                 = "ou=groups,${var.lldap_base_dn}"
  group_name_ldap_attribute      = "cn"
  group_object_classes           = ["groupOfUniqueNames", "top"]
  membership_attribute_type      = "DN"
  membership_ldap_attribute      = "member"
  membership_user_ldap_attribute = "uid"
  memberof_ldap_attribute        = "memberOf"
  mode                           = "READ_ONLY"
  use_realm_roles_mapping        = false
}

resource "keycloak_openid_client_scope" "groups" {
  realm_id               = keycloak_realm.homelab.id
  name                   = "groups"
  include_in_token_scope = true
}

resource "keycloak_openid_group_membership_protocol_mapper" "groups" {
  realm_id        = keycloak_realm.homelab.id
  client_scope_id = keycloak_openid_client_scope.groups.id
  name            = "groups"
  claim_name      = "groups"
  full_path       = false

  add_to_id_token     = true
  add_to_access_token = true
  add_to_userinfo     = true
}

# Scoped service-account client used by components/oidc-client to manage OIDC
# clients in the homelab realm without fanning out master admin credentials.
resource "keycloak_openid_client" "oidc_provisioner" {
  realm_id  = keycloak_realm.homelab.id
  client_id = "oidc-provisioner"
  name      = "OIDC Client Provisioner"
  enabled   = true

  access_type              = "CONFIDENTIAL"
  standard_flow_enabled    = false
  service_accounts_enabled = true
}

data "keycloak_openid_client" "realm_management" {
  realm_id  = keycloak_realm.homelab.id
  client_id = "realm-management"
}

resource "keycloak_openid_client_service_account_role" "oidc_provisioner_manage_clients" {
  realm_id                = keycloak_realm.homelab.id
  service_account_user_id = keycloak_openid_client.oidc_provisioner.service_account_user_id
  client_id               = data.keycloak_openid_client.realm_management.id
  role                    = "manage-clients"
}

output "OIDC_PROVISIONER_CLIENT_ID" {
  value = keycloak_openid_client.oidc_provisioner.client_id
}

output "OIDC_PROVISIONER_CLIENT_SECRET" {
  value     = keycloak_openid_client.oidc_provisioner.client_secret
  sensitive = true
}
