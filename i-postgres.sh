#!/usr/bin/env bash

# check for root
if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root."
    exit 1
fi

apt update

apt install -y postgresql postgresql-contrib

systemctl start postgresql.service

# sudo -u postgres createuser --interactive
# psql -U tim -W postgres
