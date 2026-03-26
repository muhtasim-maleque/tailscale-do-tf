resource "digitalocean_droplet" "tailscale" {
  image    = var.ubuntu_image
  name     = "tailscalesubnet"
  region   = var.region
  size     = var.droplet_size
  ssh_keys = [var.ssh_key_id]

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
}