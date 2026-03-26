output "tailscale_droplet_ip" {
  description = "Public IP of the subnet router"
  value       = digitalocean_droplet.tailscale.ipv4_address
}

output "basic_droplet_private_ip" {
  description = "Private IP of the target device to test routing"
  value       = digitalocean_droplet.basic.ipv4_address_private
}