data "cloudflare_zones" "chobert_net" {
  filter {
    name   = "chobert.net"
    status = "active"
  }
}

resource "cloudflare_record" "instance_record" {
  count = length(hcloud_server.master)

  zone_id = data.cloudflare_zones.chobert_net.zones[0].id
  name    = hcloud_server.master[count.index].name
  value   = hcloud_server.master[count.index].ipv4_address
  type    = "A"
  ttl     = 1
}

resource "cloudflare_record" "lb_record" {
  zone_id = data.cloudflare_zones.chobert_net.zones[0].id
  name    = "lb.kube"
  value   = hcloud_floating_ip.lb.ip_address
  type    = "A"
  ttl     = 1
}
