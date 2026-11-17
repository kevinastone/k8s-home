terraform {
  required_version = ">= 1.10.0"
  required_providers {
    rustfs = {
      source  = "caberdo/rustfs"
      version = "~> 0.10"
    }
  }
}

provider "rustfs" {
  endpoint   = var.rustfs_server
  access_key = var.RUSTFS_ACCESS_KEY
  secret_key = var.RUSTFS_SECRET_KEY
}
