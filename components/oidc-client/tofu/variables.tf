variable "keycloak_url" {
  type        = string
  description = "Internal Keycloak HTTP URL"
  default     = "http://keycloak.keycloak.svc.cluster.local:8080"
}

variable "realm" {
  type        = string
  description = "Keycloak realm name"
  default     = "homelab"
}

variable "OIDC_PROVISIONER_CLIENT_ID" {
  type        = string
  description = "Scoped Keycloak service-account client ID"
}

variable "OIDC_PROVISIONER_CLIENT_SECRET" {
  type        = string
  description = "Scoped Keycloak service-account client secret"
  sensitive   = true
}

variable "OIDC_CLIENT_SECRET" {
  type        = string
  description = "OIDC client secret for the provisioned client"
  sensitive   = true
}

variable "client_id" {
  type        = string
  description = "OIDC client ID"
}

variable "client_name" {
  type        = string
  description = "Human-readable OIDC client display name"
}

variable "redirect_uris" {
  type        = list(string)
  description = "Allowed OIDC redirect URIs"
}

variable "web_origins" {
  type        = list(string)
  description = "Allowed CORS web origins"
  default     = ["+"]
}
