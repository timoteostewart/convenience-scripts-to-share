#!/usr/bin/env bash

# check for root
if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root."
    exit
fi

##
##
## install openssh
##
##

apt update
apt install -y openssh-server

# check for error
if [[ $? -ne 0 ]] ; then
    echo "Error: Failed to install OpenSSH server."
    echo "Aborting script."
    exit 1
fi

systemctl start ssh
systemctl enable ssh
systemctl status ssh

ufw allow ssh

# allow root login
sed -i 's/^#PermitRootLogin prohibit-password/PermitRootLogin yes/g' /etc/ssh/sshd_config
systemctl restart sshd

# display ip address
hostname -I
