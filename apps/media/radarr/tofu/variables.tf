variable "radarr_url" {
  type        = string
  description = "Radarr API URL"
  default     = "http://radarr:7878"
}

variable "api_key" {
  type        = string
  description = "Radarr API key"
  sensitive   = true
}

variable "root_folder_path" {
  type        = string
  description = "Radarr root folder path"
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

variable "sabnzbd_movie_category" {
  type        = string
  description = "SABnzbd category for movies"
  default     = "movies"
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
