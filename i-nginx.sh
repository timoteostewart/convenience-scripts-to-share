#!/usr/bin/env bash

# check for root
if [[ $(id -u) != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

die () {
    if [[ ! -z "$1" ]]; then
        mesg=$1
    else
        mesg=""
    fi
    echo -e "\n*\n* ${mesg}"
    echo -e "* An unrecoverable error has occurred. Look above for any error messages."
    echo -e "* The script \`${BASH_SOURCE##*/}\` will exit now.\n*\n"
    exit 1
}

add-apt-repository -y ppa:ondrej/nginx-mainline
apt update

if ! apt install -y nginx; then
    die "Error: Nginx failed to install."
fi

if ! nginx -v; then
    die "Error: Nginx seemed to install, but \`nginx -v\` failed."
fi
if ! systemctl start nginx.service; then
    die "Error: \`nginx.service\` failed to start."
fi

ufw allow http
ufw allow https
ufw --force enable
ufw status

systemctl status nginx.service
systemctl enable nginx.service

echo -e "\n*"
echo -e "* Nginx installation seems to be successful."
echo -e "*"
echo -e "* Check it out:  http://$(hostname -I)"
echo -e "*\n"

exit 0

################################################################################
################################################################################

Next steps:

