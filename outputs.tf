output "basic_droplet_private_ip" {
  description = "Private IP of the target device to test routing"
  value       = digitalocean_droplet.basic.ipv4_address_private
}

output "vpc_ip_range" {
  description = "The exact CIDR to use for --advertise-routes"
  value       = data.digitalocean_vpc.selected.ip_range
}