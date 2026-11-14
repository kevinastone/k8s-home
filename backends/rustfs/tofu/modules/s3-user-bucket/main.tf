terraform {
  required_version = ">= 1.10.0"
  required_providers {
    rustfs = {
      source  = "caberdo/rustfs"
      version = "~> 0.8"
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

resource "rustfs_bucket" "bucket" {
  name = var.name
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
  status     = "enabled"

  lifecycle {
    ignore_changes = [secret_key]
    replace_triggered_by = [
      terraform_data.secret_rotation,
      terraform_data.user_replacement
    ]
  }
}

resource "rustfs_user_policy_attachment" "attachment" {
  user   = rustfs_user.user.access_key
  policy = rustfs_policy.policy.name
}

resource "terraform_data" "secret_rotation" {
  input = var.secret
}

resource "terraform_data" "user_replacement" {
  input = var.name
}
