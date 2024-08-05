#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exit status; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

# install dependencies
dependencies_to_install=(
    ca-certificates
    software-properties-common
)
install_apt_packages "${dependencies_to_install[@]}"

add-apt-repository -y ppa:ondrej/apache2
apt-get -y update

apt-get -y install apache2 apache2-dev || die "Error: Apache2 failed to install."
program-not-available apache2 || die "Error: Apache2 seemed to install, but \`apache2\` doesn't seem available."
systemctl start apache2 || die "Error: \`apache2\` service failed to start."
systemctl enable apache2 || die "Error: Failed to enable \`apache2\` service."

if is-ufw-active; then
    # ufw allow 32400/tcp

    cat <<EOF >"/etc/ufw/applications.d/plexmediaserver"
[apache2]
title=Apache Web Server
description=Apache HTTP Server
ports=80/tcp

[apache2-secure]
title=Apache Web Server (HTTPS)
description=Apache HTTP Server with SSL/TLS enabled
ports=443/tcp

EOF

    ufw allow apache2
    ufw allow apache2-secure
    ufw reload

fi

default_interface=$(get-name-of-default-interface)
hostname_ip_address=$(get-ip-address-for-interface "${default_interface}")

printf "
* Apache2 installation seems to be successful.
*
* Apache2 version: $(apache2 -v)
* Apache2 version: $(apachectl -v)
*
* \`hostname\`:         $(hostname)
* \`hostname --fqdn\`:  $(hostname --fqdn)
* \`hostname -I\`:      ${hostname_ip_address}


Next steps:

# check status of Apache2
sudo systemctl status apache2

# run configtest
sudo apache2ctl configtest

# create a hello-world web page
sudo mkdir --parents /var/www/html/hello-world
sudo chown -R www-data:www-data /var/www/html/hello-world
sudo usermod --append --groups www-data ${SUDO_USER}
chmod -R 755 /var/www/html/hello-world
printf '<html>\n<head>\n<title>Hello</title>\n</head>\n<body>\n<p>Hello, world!</p>\n</body>\n</html>\n\n' | sudo tee /var/www/html/hello-world/index.html >/dev/null

# harden Apache2
settings=(
    "ServerSignature Off"
    "ServerTokens Prod"
    "TraceEnable Off"
)
config_file=/etc/apache2/apache2.conf
for setting in \"\${settings[@]}\"; do
    first_word=\$(echo \"\${setting}\" | awk '{print \$1}')
    if grep -q \"^\${first_word}\" \"\${config_file}\"; then
        sed -i \"s/^\${first_word}.*/\${setting}/\" \"\${config_file}\"
    else
        echo \"\$setting\" >> \"\${config_file}\"
    fi
done

"

exit 0
