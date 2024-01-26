packer {
  required_plugins {
    hcloud = {
      source  = "github.com/hetznercloud/hcloud"
      version = "~> 1"
    }
  }
}

source "hcloud" "ubuntu-zfs" {
  location = "fsn1"
  image = "ubuntu-22.04"
  rescue = "linux64"
  ssh_username = "root"
  server_type = "cax31"
  snapshot_name = "ubuntu-zfs-{{ timestamp }}"
}

build {
  sources = ["hcloud.ubuntu-zfs"]
  name = "image"

  provisioner "shell" {
    script = "./install_ubuntu_on_zfs.sh"
    expect_disconnect = true
  }

  provisioner "shell" {
    inline = [
      "echo Reboot successful.",
      "uname -a"
    ]
  }
}
