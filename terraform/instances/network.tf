resource "hcloud_network" "main_network" {
  name     = "default"
  ip_range = "10.0.0.0/16"
}

resource "hcloud_network_subnet" "main_subnet" {
  network_id   = hcloud_network.main_network.id
  type         = "cloud"
  network_zone = "eu-central"
  ip_range     = "10.0.0.0/24"
}
