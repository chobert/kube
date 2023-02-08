#!/usr/bin/env bash

set -eux

sgdisk -e /dev/sda
zypper -n addrepo -G -f https://download.opensuse.org/repositories/filesystems/openSUSE_Tumbleweed/filesystems.repo
zypper --gpg-auto-import-keys install -y zfs zfs-kmp-default parted
modprobe zfs
parted /dev/sda -- resizepart 4 80GiB
parted /dev/sda -- mkpart primary ext4 80GiB 100%
zpool create -m none datapool /dev/sda5
zfs create datapool/volumes
zfs create datapool/volumes/ext4
zfs create datapool/volumes/block
