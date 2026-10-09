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
