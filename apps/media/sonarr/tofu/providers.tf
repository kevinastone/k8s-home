terraform {
  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.5.0"
    }
  }
}

provider "sonarr" {
  url     = var.sonarr_url
  api_key = var.api_key
}
