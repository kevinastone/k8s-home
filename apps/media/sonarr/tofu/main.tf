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


