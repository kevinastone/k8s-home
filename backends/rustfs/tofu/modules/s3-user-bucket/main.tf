terraform {
  required_providers {
    minio = {
      source = "aminueza/minio"
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

resource "minio_s3_bucket" "bucket" {
  bucket = var.name
}

resource "minio_iam_user" "user" {
  name   = var.name
  secret = var.secret
}

resource "minio_accesskey" "key" {
  access_key         = var.name
  secret_key         = var.secret
  secret_key_version = 1
  user               = minio_iam_user.user.name
  policy     = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect   = "Allow"
        Action   = ["s3:*"]
        Resource = [
          "arn:aws:s3:::${var.name}",
          "arn:aws:s3:::${var.name}/*"
        ]
      }
    ]
  })
}
