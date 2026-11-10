terraform {
  required_version = ">= 1.10.0"
  required_providers {
    rustfs = {
      source  = "ethdevops/rustfs"
      version = "0.1.1"
    }
  }
}

provider "rustfs" {
  endpoint      = var.rustfs_server
  access_key    = var.RUSTFS_ACCESS_KEY
  access_secret = var.RUSTFS_SECRET_KEY
  ssl           = false
}
