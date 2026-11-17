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

module "clickhouse" {
  source = "./modules/s3-user-bucket"
  name   = "clickhouse"
  secret = var.clickhouse
}
