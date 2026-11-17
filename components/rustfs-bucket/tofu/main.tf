resource "rustfs_bucket" "bucket" {
  name          = var.AWS_ACCESS_KEY_ID
  force_destroy = var.force_destroy
}

resource "rustfs_policy" "policy" {
  name = var.AWS_ACCESS_KEY_ID
  statement = [
    {
      action = ["s3:*"]
      effect = "Allow"
      resource = [
        "arn:aws:s3:::${var.AWS_ACCESS_KEY_ID}",
        "arn:aws:s3:::${var.AWS_ACCESS_KEY_ID}/*"
      ]
    }
  ]
}

resource "rustfs_user" "user" {
  access_key = var.AWS_ACCESS_KEY_ID
  secret_key = var.AWS_SECRET_ACCESS_KEY
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
  input = var.AWS_SECRET_ACCESS_KEY
}

resource "terraform_data" "user_replacement" {
  input = var.AWS_ACCESS_KEY_ID
}

moved {
  from = module.bucket.rustfs_bucket.bucket
  to   = rustfs_bucket.bucket
}

moved {
  from = module.bucket.rustfs_policy.policy
  to   = rustfs_policy.policy
}

moved {
  from = module.bucket.rustfs_user.user
  to   = rustfs_user.user
}

moved {
  from = module.bucket.terraform_data.secret_rotation
  to   = terraform_data.secret_rotation
}

moved {
  from = module.bucket.terraform_data.user_replacement
  to   = terraform_data.user_replacement
}
