data "remote_file" "kubeconfig" {
  conn {
    host        = hcloud_server.master["master01"].ipv4_address
    port        = 22
    user        = "root"
    private_key = tls_private_key.provisioning.private_key_openssh
  }
  path = "/etc/rancher/k3s/k3s.yaml"

  depends_on = [null_resource.control_planes[0]]
}

locals {
  kubeconfig_server_address = hcloud_server.master["master01"].ipv4_address
  kubeconfig_external       = replace(replace(data.remote_file.kubeconfig.content, "127.0.0.1", local.kubeconfig_server_address), "default", "kube.chobert.net")
}

