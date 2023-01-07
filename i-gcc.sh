#!/usr/bin/env bash

# check for root
if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root."
    exit 1
fi

apt-get update -y
apt-get install -y build-essential
