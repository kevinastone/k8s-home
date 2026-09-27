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
