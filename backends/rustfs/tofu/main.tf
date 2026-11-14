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

module "zot" {
  source = "./modules/s3-user-bucket"
  name   = "zot"
  secret = var.zot
}
