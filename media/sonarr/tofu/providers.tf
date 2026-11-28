terraform {
  required_version = ">= 1.10.0"
  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "3.6.0"
    }
  }
}

provider "sonarr" {
  url     = var.sonarr_url
  api_key = var.api_key
}
