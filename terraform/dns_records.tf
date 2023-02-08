data "cloudflare_zones" "chobert_net" {
  filter {
    name   = "chobert.net"
    status = "active"
  }
}

resource "cloudflare_record" "instance_record" {
  for_each = local.instance_name_set

  zone_id = data.cloudflare_zones.chobert_net.zones[0].id
  name    = local.hostname[each.key]
  value   = hcloud_server.master[each.key].ipv4_address
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
