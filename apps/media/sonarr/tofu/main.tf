resource "sonarr_root_folder" "media" {
  path = var.root_folder_path
}

resource "sonarr_download_client_config" "config" {
  enable_completed_download_handling = true
  auto_redownload_failed             = true
}

resource "sonarr_download_client_sabnzbd" "sabnzbd" {
  enable                     = true
  priority                   = 1
  name                       = "SABnzbd"
  host                       = var.sabnzbd_host
  port                       = var.sabnzbd_port
  api_key                    = var.sabnzbd_api_key
  tv_category                = var.sabnzbd_tv_category
  remove_completed_downloads = true
}

resource "sonarr_download_client_qbittorrent" "qbittorrent" {
  enable                     = false
  priority                   = 1
  name                       = "qBittorrent"
  host                       = var.qbittorrent_host
  port                       = var.qbittorrent_port
  remove_completed_downloads = true
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

resource "sonarr_naming" "naming" {
  rename_episodes            = true
  replace_illegal_characters = true
  multi_episode_style        = 0
  colon_replacement_format   = 4
  daily_episode_format       = "{Series Title} - {Air-Date} - {Episode Title} {Quality Full}"
  anime_episode_format       = "{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}"
  series_folder_format       = "{Series Title}"
  season_folder_format       = "Season {season}"
  specials_folder_format     = "Specials"
  standard_episode_format    = "{Series Title} - S{season:00}E{episode:00} - {Episode Title} {Quality Full}"
}
