module "postgres" {
  source = "./modules/s3-user-bucket"
  name   = "postgres"
  secret = var.postgres
}

module "dragonfly" {
  source = "./modules/s3-user-bucket"
  name   = "dragonfly"
  secret = var.dragonfly
}

removed {
  from = module.clickhouse.rustfs_bucket.bucket

  lifecycle {
    destroy = false
  }
}
