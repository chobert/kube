output "load_balancer_ip" {
  value = hcloud_floating_ip.lb.ip_address
}

output "master_instance_ips" {
  value = hcloud_server.master.*.ipv4_address
}
