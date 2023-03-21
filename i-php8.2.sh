#!/usr/bin/env bash

source ./functions.sh

die-if-not-root

apt-get -y update && apt-get -y upgrade
apt-get -y install apt-transport-https ca-certificates lsb-release software-properties-common
add-apt-repository -y ppa:ondrej/php
apt-get -y update

if ! apt-get -y install php8.2; then
    die "PHP 8.2 failed to install!"
    exit 1
fi
if ! php --version; then
    die "Error: PHP 8.2 seemed to install, but \`php --version\` failed."
fi

printf -- "
*
* PHP 8.2 installation seems to be successful.
*

"

exit 0

################################################################################
################################################################################

Next steps:


