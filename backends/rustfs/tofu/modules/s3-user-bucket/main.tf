terraform {
  required_version = ">= 1.10.0"
  required_providers {
    rustfs = {
      source  = "caberdo/rustfs"
      version = "~> 0.10"
    }
  }
}

variable "name" {
  type        = string
  description = "The name of the S3 bucket and IAM user"
}

variable "secret" {
  type        = string
  description = "The password/secret key for the IAM user"
  sensitive   = true
}

variable "force_destroy" {
  type        = bool
  description = "Allow Terraform to empty and destroy a non-empty bucket"
  default     = false
}

resource "rustfs_bucket" "bucket" {
  name          = var.name
  force_destroy = var.force_destroy
}

resource "rustfs_policy" "policy" {
  name = var.name
  statement = [
    {
      action = ["s3:*"]
      effect = "Allow"
      resource = [
        "arn:aws:s3:::${var.name}",
        "arn:aws:s3:::${var.name}/*"
      ]
    }
  ]
}

resource "rustfs_user" "user" {
  access_key = var.name
  secret_key = var.secret
  policy     = rustfs_policy.policy.name
  status     = "enabled"

  lifecycle {
    ignore_changes = [secret_key]
    replace_triggered_by = [
      terraform_data.secret_rotation,
      terraform_data.user_replacement
    ]
  }
}

resource "terraform_data" "secret_rotation" {
  input = var.secret
}

resource "terraform_data" "user_replacement" {
  input = var.name
}
