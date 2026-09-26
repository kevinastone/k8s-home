resource "sonarr_root_folder" "media" {
  path = var.root_folder_path
}

resource "sonarr_download_client_sabnzbd" "sabnzbd" {
  enable      = true
  priority    = 1
  name        = "SABnzbd"
  host        = var.sabnzbd_host
  port        = var.sabnzbd_port
  api_key     = var.sabnzbd_api_key
  tv_category = var.sabnzbd_tv_category
}

resource "sonarr_download_client_qbittorrent" "qbittorrent" {
  enable   = true
  priority = 1
  name     = "qBittorrent"
  host     = var.qbittorrent_host
  port     = var.qbittorrent_port
}

resource "sonarr_indexer_newznab" "nzbgeek" {
  name                      = "NZBGeek"
  enable_rss                = true
  enable_automatic_search   = true
  enable_interactive_search = true
  base_url                  = "https://api.nzbgeek.info"
  api_path                  = "/api"
  api_key                   = var.NZBGEEK_API_KEY
  categories                = [5000, 5020, 5030, 5040, 5045]
}

