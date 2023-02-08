packer {
  required_plugins {
    hcloud = {
      version = "1.0.5"
      source = "github.com/hashicorp/hcloud"
    }
  }
}

source "hcloud" "microos-base" {
  location = "nbg1"
  image = "ubuntu-20.04"
  rescue = "linux64"
  ssh_username = "root"
  server_type = "cx21"
  snapshot_name = "microos-base-{{ timestamp }}"
}

build {
  sources = ["hcloud.microos-base"]
  name = "image"

  provisioner "shell" {
    script = "./install_microos.sh"
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "echo Reboot successful.",
      "uname -a"
    ]
  }
}
