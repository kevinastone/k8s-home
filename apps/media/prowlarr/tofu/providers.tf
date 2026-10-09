terraform {
  required_providers {
    prowlarr = {
      source  = "devopsarr/prowlarr"
      version = "3.2.2"
    }
  }
}

provider "prowlarr" {
  url     = var.prowlarr_url
  api_key = var.api_key
}
