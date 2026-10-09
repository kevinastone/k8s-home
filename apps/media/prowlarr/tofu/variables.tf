variable "prowlarr_url" {
  type        = string
  description = "Prowlarr API URL"
  default     = "http://prowlarr:9696"
}

variable "api_key" {
  type        = string
  description = "Prowlarr API key"
  sensitive   = true
}

variable "NZBGEEK_API_KEY" {
  type        = string
  description = "NZBGeek API key"
  sensitive   = true
}

variable "sabnzbd_host" {
  type        = string
  description = "SABnzbd host"
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

variable "radarr_url" {
  type        = string
  description = "Radarr API URL"
  default     = "http://radarr:7878"
}

variable "radarr_api_key" {
  type        = string
  description = "Radarr API key"
  sensitive   = true
}

variable "sonarr_url" {
  type        = string
  description = "Sonarr API URL"
  default     = "http://sonarr:8989"
}

variable "sonarr_api_key" {
  type        = string
  description = "Sonarr API key"
  sensitive   = true
}

