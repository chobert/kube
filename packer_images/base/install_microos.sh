#!/usr/bin/env bash

set -eux

microos_url="https://download.opensuse.org/tumbleweed/appliances/openSUSE-MicroOS.x86_64-OpenStack-Cloud.qcow2"

wget --timeout=5 --waitretry=5 --tries=5 --retry-connrefused --inet4-only $microos_url
qemu-img convert -p -f qcow2 -O host_device $(ls -a | grep -ie '^opensuse.*microos.*qcow2$') /dev/sda
sleep 2; reboot
