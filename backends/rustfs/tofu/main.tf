removed {
  from = module.postgres.rustfs_bucket.bucket

  lifecycle {
    destroy = false
  }
}

module "dragonfly" {
  source = "./modules/s3-user-bucket"
  name   = "dragonfly"
  secret = var.dragonfly
}
