variable "rustfs_server" {
  type        = string
  description = "RustFS server endpoint"
  default     = "rustfs-main:9000"
}

variable "RUSTFS_ACCESS_KEY" {
  type        = string
  description = "RustFS access key (root)"
  sensitive   = true
}

variable "RUSTFS_SECRET_KEY" {
  type        = string
  description = "RustFS secret key (root)"
  sensitive   = true
}

variable "postgres" {
  type        = string
  description = "Postgres user password"
  sensitive   = true
}

variable "dragonfly" {
  type        = string
  description = "Dragonfly user password"
  sensitive   = true
}

variable "zot" {
  type        = string
  description = "Zot user password"
  sensitive   = true
}
