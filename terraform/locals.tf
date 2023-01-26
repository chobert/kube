locals {
  initial_k3s_channel = "v1.26"

  ccm_version   = data.github_release.hetzner_ccm.release_tag
  csi_version   = data.github_release.hetzner_csi.release_tag
  kured_version = data.github_release.kured.release_tag

  network_ipv4_cidr   = "10.0.0.0/8"
  network_ipv4_subnet = cidrsubnet(local.network_ipv4_cidr, 8, 0)

  hetzner_metadata_service_ipv4 = "169.254.169.254/32"
  hetzner_cloud_api_ipv4        = "213.239.246.1/32"

  whitelisted_ips = [
    local.network_ipv4_cidr,
    local.hetzner_metadata_service_ipv4,
    local.hetzner_cloud_api_ipv4,
    "127.0.0.1/32",
  ]

  install_k3s_server = [
    "set -ex",
    # prepare the k3s config directory
    "mkdir -p /etc/rancher/k3s",
    # move the config file into place and adjust permissions
    "mv /tmp/config.yaml /etc/rancher/k3s/config.yaml",
    "chmod 0600 /etc/rancher/k3s/config.yaml",
    # if the server has already been initialized just stop here
    "[ -e /etc/rancher/k3s/k3s.yaml ] && exit 0",
    "curl -sfL https://get.k3s.io | INSTALL_K3S_SKIP_START=true INSTALL_K3S_SKIP_SELINUX_RPM=true INSTALL_K3S_CHANNEL=${local.initial_k3s_channel} INSTALL_K3S_EXEC=server sh -"
  ]

  k3s_config_common = {
    disable-cloud-controller = true
    token                    = random_password.k3s_token.result
    disable = [
      "local-storage", # we use zfs localpv instead
      "traefik",       # we use istio ingress
      "servicelb"      # we use kube-vip
    ]
    node-taint                  = []
    write-kubeconfig-mode       = "0644"
    node-label                  = ["k3s_upgrade=true", "node.kubernetes.io/exclude-from-external-load-balancers=true"]
    kubelet-arg                 = ["cloud-provider=external", "volume-plugin-dir=/var/lib/kubelet/volumeplugins"]
    kube-controller-manager-arg = "flex-volume-plugin-dir=/var/lib/kubelet/volumeplugins"
    flannel-iface               = "eth1"

    # required for cilium
    disable-network-policy = true
    flannel-backend        = "none"
  }

  cilium_values = <<EOT
ipam:
 operator:
  clusterPoolIPv4PodCIDRList:
   - ${local.cluster_cidr_ipv4}
devices: "eth1"
  EOT

  cert_manager_values = <<EOT
installCRDs: true
  EOT
}

