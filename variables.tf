variable "tailscale_auth_key" {
  description = "Tailscale authentication key from admin console"
  type        = string
  sensitive   = true
}

variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_id" {
  description = "DigitalOcean SSH key identifier"
  type        = number
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc1"
}

variable "droplet_size" {
  description = "Hardware size of the devices"
  type        = string
  default     = "s-1vcpu-1gb"
}

variable "ubuntu_image" {
  description = "Operating system image"
  type        = string
  default     = "ubuntu-24-04-x64"
}