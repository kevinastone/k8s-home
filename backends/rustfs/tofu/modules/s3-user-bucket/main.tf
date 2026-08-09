terraform {
  required_providers {
    rustfs = {
      source = "ethdevops/rustfs"
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
      # Necessary typo
      ressource = [
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
