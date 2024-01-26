#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

apt update

DISK=$(find /dev/disk/by-id -regextype awk -regex '.+/(ata|nvme|scsi)-.+' -not -regex '.+-part[0-9]+$' | head -n 1)

swapoff --all

blkdiscard -f $DISK
sgdisk --zap-all $DISK

# create booltloader partition
sgdisk -n1:1M:+512M -t1:EF00 $DISK

# create swap partition
sgdisk -n2:0:+8G -t2:8200 $DISK

# create boot patrition of 2G
sgdisk -n3:0:+2G -t3:BE00 $DISK

# create root pool partition
sgdisk -n4:0:0 -t4:BF00 $DISK

# create boot pool
zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -o cachefile=/etc/zpool.cache \
    -o compatibility=grub2 \
    -o feature@livelist=enabled \
    -o feature@zpool_checkpoint=enabled \
    -O devices=off \
    -O acltype=posixacl -O xattr=sa \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/boot -R /mnt \
    bpool ${DISK}-part3

# create root pool
zpool create \
    -o ashift=12 \
    -o autotrim=on \
    -O acltype=posixacl -O xattr=sa -O dnodesize=auto \
    -O compression=lz4 \
    -O normalization=formD \
    -O relatime=on \
    -O canmount=off -O mountpoint=/ -R /mnt \
    rpool ${DISK}-part4

# Create filesystem datasets to act as containers
zfs create -o canmount=off -o mountpoint=none rpool/ROOT
zfs create -o canmount=off -o mountpoint=none bpool/BOOT

# Create filesystem datasets for the root and boot filesystems
UUID=$(dd if=/dev/urandom bs=1 count=100 2>/dev/null |
    tr -dc 'a-z0-9' | cut -c-6)

zfs create -o mountpoint=/ \
    -o com.ubuntu.zsys:bootfs=yes \
    -o com.ubuntu.zsys:last-used=$(date +%s) rpool/ROOT/ubuntu_$UUID

zfs create -o mountpoint=/boot bpool/BOOT/ubuntu_$UUID

# Create datasets
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_$UUID/usr
zfs create -o com.ubuntu.zsys:bootfs=no -o canmount=off \
    rpool/ROOT/ubuntu_$UUID/var
zfs create rpool/ROOT/ubuntu_$UUID/var/lib
zfs create rpool/ROOT/ubuntu_$UUID/var/log
zfs create rpool/ROOT/ubuntu_$UUID/var/spool

zfs create -o canmount=off -o mountpoint=/ \
    rpool/USERDATA
zfs create -o com.ubuntu.zsys:bootfs-datasets=rpool/ROOT/ubuntu_$UUID \
    -o canmount=on -o mountpoint=/root \
    rpool/USERDATA/root_$UUID
chmod 700 /mnt/root

zfs create rpool/ROOT/ubuntu_$UUID/var/cache
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/nfs
zfs create rpool/ROOT/ubuntu_$UUID/var/tmp

zfs create rpool/ROOT/ubuntu_$UUID/var/lib/apt
zfs create rpool/ROOT/ubuntu_$UUID/var/lib/dpkg

zfs create rpool/ROOT/ubuntu_$UUID/usr/local

zfs create -o com.ubuntu.zsys:bootfs=no \
    rpool/ROOT/ubuntu_$UUID/tmp
chmod 1777 /mnt/tmp

# Mount a tmpfs at /run
mkdir /mnt/run
mount -t tmpfs tmpfs /mnt/run
mkdir /mnt/run/lock

# Install the minimal system
debootstrap --arch=arm64 jammy /mnt http://mirror.hetzner.de/ubuntu/packages

# Copy in zpool.cache
mkdir /mnt/etc/zfs
cp /etc/zpool.cache /mnt/etc/zfs/

# Configure the hostname
hostname blue.kube.chobert.net
hostname > /mnt/etc/hostname

cat > /mnt/etc/hosts <<CONF
127.0.1.1 blue.kube.chobert.net blue
127.0.0.1 localhost

# The following lines are desirable for IPv6 capable hosts
::1 ip6-localhost ip6-loopback
fe00::0 ip6-localnet
ff00::0 ip6-mcastprefix
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
ff02::3 ip6-allhosts
CONF

ip6addr_prefix=$(ip -6 a s | grep -E "inet6.+global" | sed -nE 's/.+inet6\s(([0-9a-z]{1,4}:){4,4}).+/\1/p' | head -n 1)

cat <<CONF > /mnt/etc/systemd/network/10-eth0.network
[Match]
Name=eth0

[Network]
DHCP=ipv4
Address=${ip6addr_prefix}:1/64
Gateway=fe80::1
CONF

mkdir -p /mnt/etc/cloud/cloud.cfg.d/
cat > /mnt/etc/cloud/cloud.cfg.d/99-disable-network-config.cfg <<CONF
network:
  config: disabled
CONF

rm -rf /mnt/etc/network/interfaces.d/50-cloud-init.cfg

c_deb_packages_repo=http://mirror.hetzner.de/ubuntu/packages
c_deb_security_repo=http://mirror.hetzner.de/ubuntu/security

cat > "/mnt/etc/apt/sources.list" <<CONF
deb [arch=arm64] $c_deb_packages_repo jammy main restricted
deb [arch=arm64] $c_deb_packages_repo jammy-updates main restricted
deb [arch=arm64] $c_deb_packages_repo jammy-backports main restricted
deb [arch=arm64] $c_deb_packages_repo jammy universe
deb [arch=arm64] $c_deb_security_repo jammy-security main restricted
CONF

function chroot_execute {
  chroot /mnt bash -c "$1"
}

chroot_execute "apt update"

chroot_execute 'cat <<CONF | debconf-set-selections
locales locales/default_environment_locale      select  en_US.UTF-8
CONF'

chroot_execute "dpkg-reconfigure locales -f noninteractive"
echo -e "LC_ALL=en_US.UTF-8\nLANG=en_US.UTF-8\n" >> /mnt/etc/environment
chroot_execute "dpkg-reconfigure keyboard-configuration -f noninteractive"
chroot_execute "dpkg-reconfigure console-setup -f noninteractive"
chroot_execute "setupcon"

chroot_execute "rm -f /etc/localtime /etc/timezone"
chroot_execute "dpkg-reconfigure tzdata -f noninteractive"

# # Create the EFI filesystem
# apt install --yes dosfstools

# mkdosfs -F 32 -s 1 -n EFI ${DISK}-part1
# mkdir /boot/efi
# echo /dev/disk/by-uuid/$(blkid -s UUID -o value ${DISK}-part1) \
#     /boot/efi vfat defaults 0 0 >> /etc/fstab
# mount /boot/efi

# # Put /boot/grub on the EFI System Partition
# mkdir /boot/efi/grub /boot/grub
# echo /boot/efi/grub /boot/grub none defaults,bind 0 0 >> /etc/fstab
# mount /boot/grub

# chroot_execute "DEBIAN_FRONTEND=noninteractive apt install --yes linux-headers-virtual linux-image-virtual linux-image-extra-virtual grub-efi-arm64 grub-efi-arm64-signed shim-signed zfs-initramfs zsys"

# chroot_execute "apt install --yes man-db wget curl software-properties-common nano htop gnupg"
# chroot_execute "systemctl disable thermald"

# chroot_execute 'echo "zfs-dkms zfs-dkms/note-incompatible-licenses note true" | debconf-set-selections'
