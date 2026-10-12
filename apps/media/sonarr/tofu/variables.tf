variable "sonarr_url" {
  type        = string
  description = "Sonarr API URL"
  default     = "http://sonarr:8989"
}

variable "api_key" {
  type        = string
  description = "Sonarr API key"
  sensitive   = true
}

variable "root_folder_path" {
  type        = string
  description = "Sonarr root folder path"
  default     = "/storage/media"
}

variable "sabnzbd_host" {
  type        = string
  description = "SABnzbd hostname or service name"
  default     = "sabnzbd"
}

variable "sabnzbd_port" {
  type        = number
  description = "SABnzbd port"
  default     = 8080
}

variable "sabnzbd_api_key" {
  type        = string
  description = "SABnzbd API key"
  sensitive   = true
}


variable "sabnzbd_tv_category" {
  type        = string
  description = "SABnzbd category for TV"
  default     = "tv"
}

variable "NZBGEEK_API_KEY" {
  type        = string
  description = "NZBGeek API key"
  sensitive   = true
}


variable "qbittorrent_host" {
  type        = string
  description = "qBittorrent hostname or service name"
  default     = "qbittorrent"
}

variable "qbittorrent_port" {
  type        = number
  description = "qBittorrent port"
  default     = 8080
}

