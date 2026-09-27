resource "radarr_root_folder" "media" {
  path = var.root_folder_path
}

resource "radarr_download_client_config" "config" {
  enable_completed_download_handling = true
  auto_redownload_failed             = true
}

resource "radarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = var.sabnzbd_host
  port                       = var.sabnzbd_port
  api_key                    = var.sabnzbd_api_key
  movie_category             = var.sabnzbd_movie_category
  remove_completed_downloads = true
}

resource "radarr_download_client_qbittorrent" "qbittorrent" {
  enable                     = false
  priority                   = 1
  name                       = "qBittorrent"
  host                       = var.qbittorrent_host
  port                       = var.qbittorrent_port
  remove_completed_downloads = true
}

resource "radarr_indexer_newznab" "nzbgeek" {
  name                      = "NZBGeek"
  enable_rss                = true
  enable_automatic_search   = true
  enable_interactive_search = true
  base_url                  = "https://api.nzbgeek.info"
  api_path                  = "/api"
  api_key                   = var.NZBGEEK_API_KEY
  categories                = [2000, 2010, 2020, 2030, 2040, 2045, 2050, 2060]
}
