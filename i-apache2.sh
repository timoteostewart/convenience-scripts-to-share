#!/usr/bin/env bash

# check for root
if [[ $(id -u) != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

die () {
    if [[ -n "$1" ]]; then
        mesg=$1
    else
        mesg=""
    fi
    echo -e "\n*\n* ${mesg}"
    echo -e "* An unrecoverable error has occurred. Look above for any error messages."
    echo -e "* The script \`${BASH_SOURCE##*/}\` will exit now.\n*\n"
    exit 1
}

echo -e "\n*\n* Installing Apache2...\n*\n"

apt update
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
add-apt-repository -y ppa:ondrej/apache2
apt update

if ! apt install -y apache2 apache2-dev; then
    die "Error: Apache2 failed to install."
fi
if ! apache2 -v; then
    die "Error: Apache2 seemed to install, but \`apache2 -v\` failed."
fi
if ! systemctl start apache2; then
    die "Error: \`apache2\` service failed to start."
fi

# ufw allow "Apache Full"
# ufw --force enable
ufw status

systemctl enable apache2
# systemctl status apache2

echo -e "\n*\n* Done installing Apache2.\n*"
echo -e "* Apache2 installation seems to be successful."
echo -e "* Output of 'hostname -I': $(hostname -I)\n*\n"


exit 0

################################################################################
################################################################################

Next steps:

