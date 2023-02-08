output "load_balancer_ip" {
  value = hcloud_floating_ip.lb.ip_address
}

output "master_instance_ips" {
  value = [for master in hcloud_server.master : master.ipv4_address]
}

output "kubeconfig" {
  value     = local.kubeconfig_external
  sensitive = true
}
