terraform {
  required_providers {
    radarr = {
      source  = "devopsarr/radarr"
      version = "2.5.0"
    }
  }
}

provider "radarr" {
  url     = var.radarr_url
  api_key = var.api_key
}
