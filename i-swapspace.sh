#!/usr/bin/env bash

# check for root
if [[ $(id -u) != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

# based on https://www.digitalocean.com/community/tutorials/how-to-add-swap-space-on-ubuntu-22-04

fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile

sysctl vm.swappiness=10
sysctl vm.vfs_cache_pressure=50

swapon --show
free -h

cp /etc/fstab /etc/fstab.bak

# make swapfile and settings persistent
echo '/swapfile none swap sw 0 0' | tee -a /etc/fstab
echo 'vm.swappiness=10' | tee -a /etc/sysctl.conf
echo 'vm.vfs_cache_pressure=50' | tee -a /etc/sysctl.conf

