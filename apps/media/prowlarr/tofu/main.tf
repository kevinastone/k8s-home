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
      name       = "apiKey"
      text_value = var.NZBGEEK_API_KEY
    },
    {
      name      = "categories"
      set_value = [5000, 5020, 5030, 5040, 5045]
    }
  ]
}
