#!/usr/bin/env bash

# installs PHP 8.1

# check for root
if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root."
    exit 1
fi

die () {
    if [[ -n "$1" ]]; then
        mesg=$1
    else
        mesg=""
    fi
    echo -e "\n\n*\n* ${mesg}"
    echo -e "* An unrecoverable error has occurred. Look above for any error messages."
    echo -e "* The script \`${BASH_SOURCE##*/}\` will exit now.\n*\n*\n"
    exit 1
}

echo -e "\n*"
echo -e "* Installing PHP..."
echo -e "*\n"

apt update
apt install -y lsb-release ca-certificates apt-transport-https software-properties-common
add-apt-repository -y ppa:ondrej/php

apt update
if ! apt install -y php8.1; then
    die "PHP 8.1 failed to install!"
    exit 1
fi
if ! php --version; then
    die "Error: PHP 8.1 seemed to install, but \`php --version\` failed."
fi

echo -e "\n*"
echo -e "* Done installing PHP"
echo -e "*\n"

exit 0

################################################################################
################################################################################

Next steps:


