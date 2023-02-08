packer {
  required_plugins {
    hcloud = {
      version = "1.0.5"
      source = "github.com/hashicorp/hcloud"
    }
  }
}

variable "base_image" {}

source "hcloud" "microos-final" {
  location = "nbg1"
  image = var.base_image
  ssh_username = "root"
  server_type = "cx41"
  snapshot_name = "microos-final-{{ timestamp }}"
}

build {
  sources = ["hcloud.microos-final"]

  provisioner "file" {
    source = "./finalize.sh"
    destination = "/root/finalize.sh"
  }

  provisioner "shell" {
    expect_disconnect = true
    inline = [
      "cat /root/finalize.sh | transactional-update shell",
      "sleep 10; reboot"
    ]
  }
}

