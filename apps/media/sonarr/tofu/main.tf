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
