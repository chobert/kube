data "template_file" "cloud_init" {
  count    = var.instance_count
  template = file("./cloud-config.yml")

  vars = {
    hostname    = "${format("master%02d", count.index + 1)}.kube.chobert.net"
    floating_ip = hcloud_floating_ip.lb.ip_address
  }
}

resource "hcloud_server" "master" {
  count = length(data.template_file.cloud_init)

  name        = data.template_file.cloud_init[count.index].vars.hostname
  server_type = "cx41"
  image       = "ubuntu-20.04"
  location    = "nbg1"

  ssh_keys = [hcloud_ssh_key.paul.id]

  network {
    network_id = hcloud_network.main_network.id
    ip         = cidrhost(hcloud_network_subnet.main_subnet.ip_range, count.index + 11)
  }

  user_data = data.template_file.cloud_init[count.index].rendered
}

resource "hcloud_ssh_key" "paul" {
  name       = "Paul Key"
  public_key = file("./paul_ssh.pub")
}
