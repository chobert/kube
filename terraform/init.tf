resource "null_resource" "kustomization" {
  connection {
    type        = "ssh"
    user        = "root"
    private_key = tls_private_key.provisioning.private_key_openssh
    host        = hcloud_server.master["master01"].ipv4_address
  }

  provisioner "file" {
    content = yamlencode({
      apiVersion = "kustomize.config.k8s.io/v1beta1"
      kind       = "Kustomization"

      resources = [
        "https://github.com/hetznercloud/hcloud-cloud-controller-manager/releases/download/${local.ccm_version}/ccm-networks.yaml",
        "https://github.com/weaveworks/kured/releases/download/${local.kured_version}/kured-${local.kured_version}-dockerhub.yaml",
        "https://raw.githubusercontent.com/rancher/system-upgrade-controller/master/manifests/system-upgrade-controller.yaml",
        "cilium.yaml",
        "cert_manager.yaml"
      ],
      patchesStrategicMerge = [
        "ccm.yaml",
      ]
    })

    destination = "/var/post_install/kustomization.yaml"
  }

  provisioner "file" {
    content = templatefile(
      "${path.module}/templates/cilium.yaml.tpl",
      {
        values = indent(4, trimspace(local.cilium_values))
    })
    destination = "/var/post_install/cilium.yaml"
  }

  provisioner "file" {
    content = templatefile(
      "${path.module}/templates/cert_manager.yaml.tpl",
      {
        values = indent(4, trimspace(local.cert_manager_values))
    })
    destination = "/var/post_install/ciliucert_manager.yaml"
  }

  provisioner "file" {
    content = templatefile(
      "${path.module}/templates/ccm.yaml.tpl",
      {
        cluster_cidr_ipv4   = local.cluster_cidr_ipv4
        default_lb_location = var.load_balancer_location
        using_klipper_lb    = local.using_klipper_lb

    })
    destination = "/var/post_install/ccm.yaml"
  }

  provisioner "file" {
    content = templatefile(
      "${path.module}/templates/kured.yaml.tpl",
      {
        options = local.kured_options
      }
    )
    destination = "/var/post_install/kured.yaml"
  }

  provisioner "remote-exec" {
    inline = [
      "set -ex",
      "kubectl -n kube-system create secret generic hcloud --from-literal=token=${var.hcloud_token} --from-literal=network=${hcloud_network.k3s.name} --dry-run=client -o yaml | kubectl apply -f -",
      "kubectl -n kube-system create secret generic hcloud-csi --from-literal=token=${var.hcloud_token} --dry-run=client -o yaml | kubectl apply -f -",
      "curl https://raw.githubusercontent.com/hetznercloud/csi-driver/${local.csi_version}/deploy/kubernetes/hcloud-csi.yml | sed -e 's|k8s.gcr.io|registry.k8s.io|g' > /var/post_install/hcloud-csi.yml"
    ]
  }

  # Deploy our post-installation kustomization
  provisioner "remote-exec" {
    inline = concat([
      "set -ex",

      # This ugly hack is here, because terraform serializes the
      # embedded yaml files with "- |2", when there is more than
      # one yamldocument in the embedded file. Kustomize does not understand
      # that syntax and tries to parse the blocks content as a file, resulting
      # in weird errors. so gnu sed with funny escaping is used to
      # replace lines like "- |3" by "- |" (yaml block syntax).
      # due to indendation this should not changes the embedded
      # manifests themselves
      "sed -i 's/^- |[0-9]\\+$/- |/g' /var/post_install/kustomization.yaml",

      # Wait for k3s to become ready (we check one more time) because in some edge cases,
      # the cluster had become unvailable for a few seconds, at this very instant.
      <<-EOT
      timeout 180 bash <<EOF
        until [[ "\$(kubectl get --raw='/readyz' 2> /dev/null)" == "ok" ]]; do
          echo "Waiting for the cluster to become ready..."
          sleep 2
        done
      EOF
      EOT
      ]
      ,

      [
        # Ready, set, go for the kustomization
        "kubectl apply -k /var/post_install",
        "echo 'Waiting for the system-upgrade-controller deployment to become available...'",
        "kubectl -n system-upgrade wait --for=condition=available --timeout=180s deployment/system-upgrade-controller",
        "sleep 5", # important as the system upgrade controller CRDs sometimes don't get ready right away, especially with Cilium.
        "kubectl -n system-upgrade apply -f /var/post_install/plans.yaml"
      ],
    )
  }

  depends_on = [
    null_resource.first_control_plane,
  ]
}
