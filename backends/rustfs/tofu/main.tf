module "postgres" {
  source = "./modules/s3-user-bucket"
  name   = "postgres"
  secret = var.postgres
}
