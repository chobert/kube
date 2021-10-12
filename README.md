# kube.chobert.net

This is an educational project.

- Hetzner Cloud hosting
- Kubernetes with microk8s
- Storage provided by OpenEBS ZFS PV

## Features

- [x] cert-manager
- [x] Istio service mesh & Ingress
- [x] ZFS Storage Class
- [x] Prometheus & Grafana
- [x] Keycloak
- [ ] Gitpod
- [ ] Plex
- [ ] Bittorent client
- [ ] Email hosting

## Storage configuration

Each hetzner CX41 instance is attached with a 160BG disk.

```
Disk /dev/sda: 152.6 GiB, 163842097152 bytes, 320004096 sectors
Disk model: QEMU HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt
Disk identifier: 32ADE5F4-22FA-4282-8A18-0B070D1EE362

Device        Start       End   Sectors   Size Type
/dev/sda1    528384  80001023  79472640  37.9G Linux filesystem
/dev/sda2  80001024 320002047 240001024 114.5G Linux filesystem
/dev/sda14     2048      4095      2048     1M BIOS boot
/dev/sda15     4096    528383    524288   256M EFI System
```
