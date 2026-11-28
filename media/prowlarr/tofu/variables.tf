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



