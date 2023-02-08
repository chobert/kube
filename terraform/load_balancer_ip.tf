resource "hcloud_floating_ip" "lb" {
  name          = "lb"
  type          = "ipv4"
  home_location = var.location
}

resource "hcloud_floating_ip_assignment" "main" {
  floating_ip_id = hcloud_floating_ip.lb.id
  server_id      = hcloud_server.master["master01"].id

  lifecycle {
    ignore_changes = [server_id]
  }
}
