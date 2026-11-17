variable "rustfs_server" {
  type        = string
  description = "RustFS server endpoint"
  default     = "rustfs-main.rustfs.svc.cluster.local:9000"
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

variable "AWS_ACCESS_KEY_ID" {
  type        = string
  description = "The name of the S3 bucket and IAM user"
}

variable "AWS_SECRET_ACCESS_KEY" {
  type        = string
  description = "The password/secret key for the IAM user"
  sensitive   = true
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to empty and destroy a non-empty bucket"
  default     = false
}
