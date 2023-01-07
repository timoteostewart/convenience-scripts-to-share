#!/usr/bin/env bash

# check for root
if [[ $(id -u) -ne 0 ]] ; then
    echo "Please run this script as root."
    print_usage
    exit 1
fi

go_binary_url=https://go.dev/dl/go1.18.linux-amd64.tar.gz
go_binary_filename=$(echo "${go_binary_url}" | sed "s|https://go.dev/dl/||")

# curl -L "${go_binary_url}"" | dd of="/tmp/${go_binary_filename}"
curl --fail --location --silent --show-error --output "/tmp/${go_binary_filename}" --url "${go_binary_url}"

tar -C /usr/local -xvf "/tmp/${go_binary_filename}"

# update path for root
echo -e "" >> /root/.bashrc_local
echo -e 'export PATH=$PATH:/usr/local/go/bin' >> /root/.bashrc_local
echo -e "" >> /root/.bashrc_local

# update path for ${SUDO_USER}
sudo -u "${SUDO_USER}" echo -e "" >> "/home/${SUDO_USER}/.bashrc_local"
sudo -u "${SUDO_USER}" echo -e 'export PATH=$PATH:/usr/local/go/bin' >> "/home/${SUDO_USER}/.bashrc_local"
sudo -u "${SUDO_USER}" echo -e "" >> "/home/${SUDO_USER}/.bashrc_local"

echo -e ""
echo -e "Output of \`go version\`: $(/usr/local/go/bin/go version 2>&1)"
echo -e ""
/usr/local/go/bin/go version > /dev/null 2>&1
if [[ $? -ne 0 ]] ; then
    echo "Error installing go."
    echo "Aborting script."
    exit 1
fi

echo -e "*"
echo -e "* Go was installed successfully."
echo -e "* Now please run \`source ~/.bashrc_local\` to update your path."
echo -e "*"
echo -e ""

exit 0
