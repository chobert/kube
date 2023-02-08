# kube.chobert.net

## Architecture

- [x] Hetzner cloud hosting
- [x] Hetzner private network
- [x] MicroOS
- [x] K3S
- [x] Hetzner CCM
- [x] Cilium networking
- [x] Kube-vip
- [x] Istio Service Mesh
- [x] Istio Ingress
- [x] Cert Manager
- [x] ZFS local volumes
- [x] Hetzner volumes
- [x] Postgres Operator PGO
- [x] Minio Operator

## Services

- [x] Postgres Main Cluster
  - [ ] Automated backups
- [x] Keycloak → [id.chobert.fr](https://id.chobert.fr)
- [x] Matrix -> [matrix.chobert.fr](https://matrix.chobert.fr)
- [x] Prometheus & Grafana → [grafana.chobert.fr](https://gitlab.chobert.fr)
- [x] Main Minio Tenant → [minio.chobert.fr](https://minio.chobert.fr)
- [x] Gitlab → [gitlab.chobert.fr](https://gitlab.chobert.fr)

## Storage configuration

Each hetzner CX41 instance is attached with a 160BG disk.

```
Disk /dev/sda: 152.59 GiB, 163842097152 bytes, 320004096 sectors
Disk model: QEMU HARDDISK
Units: sectors of 1 * 512 = 512 bytes
Sector size (logical/physical): 512 bytes / 512 bytes
I/O size (minimum/optimal): 512 bytes / 512 bytes
Disklabel type: gpt

Device         Start       End   Sectors  Size Type
/dev/sda1       2048      6143      4096    2M BIOS boot
/dev/sda2       6144     47103     40960   20M EFI System
/dev/sda3      47104  39827455  39780352   19G Linux filesystem
/dev/sda4   39827456 167772159 127944704   61G Linux filesystem
/dev/sda5  167772160 320002047 152229888 72.6G Linux filesystem
```
