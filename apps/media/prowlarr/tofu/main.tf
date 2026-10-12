resource "prowlarr_indexer" "nzbgeek" {
  enable          = true
  name            = "NZBGeek"
  implementation  = "Newznab"
  config_contract = "NewznabSettings"
  protocol        = "usenet"
  app_profile_id  = 1
  priority        = 1
  redirect        = true

  fields = [
    {
      name       = "baseUrl"
      text_value = "https://api.nzbgeek.info"
    },
    {
      name       = "apiPath"
      text_value = "/api"
    },
    {
      name            = "apiKey"
      sensitive_value = var.NZBGEEK_API_KEY
    },
    {
      name         = "baseSettings.limitsUnit"
      number_value = 0
    },
    {
      name       = "vipExpiration"
      text_value = ""
    }
  ]
}

resource "prowlarr_download_client_sabnzbd" "sabnzbd" {
  enable   = true
  priority = 1
  name     = "SABnzbd"
  host     = var.sabnzbd_host
  port     = var.sabnzbd_port
  api_key  = var.sabnzbd_api_key
  category = "*"
}

resource "terraform_data" "prowlarr_api_key" {
  input = var.api_key
}

resource "prowlarr_application_radarr" "radarr" {
  name         = "Radarr"
  sync_level   = "fullSync"
  base_url     = var.radarr_url
  prowlarr_url = var.prowlarr_url
  api_key      = var.radarr_api_key

  lifecycle {
    replace_triggered_by = [
      terraform_data.prowlarr_api_key
    ]
  }
}

resource "prowlarr_application_sonarr" "sonarr" {
  name         = "Sonarr"
  sync_level   = "fullSync"
  base_url     = var.sonarr_url
  prowlarr_url = var.prowlarr_url
  api_key      = var.sonarr_api_key

  lifecycle {
    replace_triggered_by = [
      terraform_data.prowlarr_api_key
    ]
  }
}


