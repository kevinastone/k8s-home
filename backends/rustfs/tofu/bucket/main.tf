module "bucket" {
  source = "../modules/s3-user-bucket"
  name   = var.AWS_ACCESS_KEY_ID
  secret = var.AWS_SECRET_ACCESS_KEY
}

# Temporary import to adopt the existing clickhouse bucket from backends/rustfs/tofu
import {
  to = module.bucket.rustfs_bucket.bucket
  id = "clickhouse"
}
