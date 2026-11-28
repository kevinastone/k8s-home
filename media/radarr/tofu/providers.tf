terraform {
  required_version = ">= 1.10.0"
  required_providers {
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.6.0"
    }
  }
}

provider "radarr" {
  url     = var.radarr_url
  api_key = var.api_key
}
