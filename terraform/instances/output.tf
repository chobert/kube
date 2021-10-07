output "master01_ip" {
  value = hcloud_server.master[0].ipv4_address
}
