resource "digitalocean_vpc" "interview_network" {
  name     = "tailscale-interview-vpc"
  region   = var.region
  ip_range = "10.10.10.0/24"
}

resource "digitalocean_droplet" "tailscale" {
  image    = var.ubuntu_image
  name     = "tailscalesubnet"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_key_id]
  vpc_uuid = digitalocean_vpc.interview_network.id

  user_data = templatefile("cloud_init.tftpl", {
    tailscale_auth_key = var.tailscale_auth_key
    advertise_routes   = digitalocean_vpc.interview_network.ip_range
  })
}

resource "digitalocean_droplet" "basic" {
  image    = var.ubuntu_image
  name     = "basicubuntu"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_key_id]
  vpc_uuid = digitalocean_vpc.interview_network.id
}