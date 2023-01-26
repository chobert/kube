locals {
  instance_name     = [for i in range(var.instances_count) : format("master%02d", i + 1)]
  instance_name_set = toset(local.instance_name)
  hostname          = { for name in isntance_name : name => "${name}.kube.chobert.net" }
}

resource "tls_private_key" "provisioning" {
  algorithm = "RSA"
  rsa_bits  = 4096
}


data "hcloud_image" "microos_final" {
  id = "97380413"
}

resource "hcloud_placement_group" "master" {
  name = "master"
  type = "spread"
}

resource "hcloud_server" "master" {
  for_each = local.instance_name_set

  name               = local.hostname[each.key]
  server_type        = "cx41"
  image              = data.hcloud_image.microos_final.id
  placement_group_id = hcloud_placement_group.master.id
  location           = var.location

  ssh_keys = [hcloud_ssh_key.paul.id, hcloud_ssh_key.provisioning.id]

  user_data = templatefile(
    "./cloud-config.yml",
    {
      hostname = locals.hostname[each.key]
    }
  )
}

resource "hcloud_server_network" "master" {
  for_each = hcloud_server.master

  server_id  = each.value.id
  network_id = hcloud_network.main_network.id
  ip         = cidrhost(hcloud_network_subnet.main_subnet.ip_range, index(local.instance_name, each.key) + 11)
}

resource "hcloud_ssh_key" "paul" {
  name       = "Paul Key"
  public_key = file("./paul_ssh.pub")
}

resource "hcloud_ssh_key" "provisioning" {
  name       = "Provisioning"
  public_key = tls_private_key.provisioning.public_key_openssh
}

resource "random_password" "k3s_token" {
  length  = 48
  special = false
}

resource "null_resource" "first_control_plane" {
  triggers = {
    server_id = hcloud_server.master["master01"].id
  }

  connection {
    type        = "ssh"
    user        = "root"
    agent       = false
    private_key = tls_private_key.provisioning.private_key_openssh
    host        = hcloud_server.master["master01"].ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 2; reboot",
    ]
  }

  provisioner "file" {
    content = yamlencode(
      merge(
        local.k3s_config_common,
        {
          node-name         = "master01"
          cluster-init      = true
          node-ip           = hcloud_server_network.master["master01"].ip
          advertise-address = hcloud_server_network.master["master01"].ip
          tls-san           = hcloud_server.master["master01"].ipv4_address
        }
      )
    )

    destination = "/tmp/config.yaml"
  }

  provisioner "remote-exec" {
    inline = local.install_k3s_server
  }

  # Upon reboot start k3s and wait for it to be ready to receive commands
  provisioner "remote-exec" {
    inline = [
      "systemctl start k3s",
      # prepare the post_install directory
      "mkdir -p /var/post_install",
      # wait for k3s to become ready
      <<-EOT
      timeout 120 bash <<EOF
        until systemctl status k3s > /dev/null; do
          systemctl start k3s
          echo "Waiting for the k3s server to start..."
          sleep 2
        done
        until [ -e /etc/rancher/k3s/k3s.yaml ]; do
          echo "Waiting for kubectl config..."
          sleep 2
        done
        until [[ "\$(kubectl get --raw='/readyz' 2> /dev/null)" == "ok" ]]; do
          echo "Waiting for the cluster to become ready..."
          sleep 2
        done
      EOF
      EOT
    ]
  }

  depends_on = [
    hcloud_server.master["master01"]
  ]
}

resource "null_resource" "control_planes" {
  for_each = hcloud_server.master

  triggers = {
    control_plane_id = each.value.id
  }

  connection {
    type        = "ssh"
    user        = "root"
    agent       = false
    private_key = tls_private_key.provisioning.private_key_openssh
    host        = each.value.ipv4_address
  }

  provisioner "remote-exec" {
    inline = [
      "sleep 2; reboot",
    ]
  }


  provisioner "file" {
    content = yamlencode(
      merge(
        local.k3s_config_common,
        {
          node-name         = each.key
          server            = "https://${hcloud_server_network.master[each.key].ip == hcloud_server_network.master[keys(hcloud_server_network.master)[0]].ip ? hcloud_server_network.master[keys(hcloud_server_network.master)[1]].ip : hcloud_server_network.master[keys(hcloud_server_network.master)[0]].ip}:6443"
          node-ip           = hcloud_server_network.master[each.key].ip
          advertise-address = hcloud_server_network.master[each.key].ip
          tls-san           = hcloud_server.master[each.key].ipv4_address
        }
      )
    )

    destination = "/tmp/config.yaml"
  }

  provisioner "remote-exec" {
    inline = local.install_k3s_server
  }

  provisioner "remote-exec" {
    inline = [
      "systemctl start k3s 2> /dev/null",
      <<-EOT
      timeout 120 bash <<EOF
        until systemctl status k3s > /dev/null; do
          systemctl start k3s 2> /dev/null
          echo "Waiting for the k3s server to start..."
          sleep 3
        done
      EOF
      EOT
    ]
  }

  depends_on = [
    null_resource.first_control_plane
  ]
}
