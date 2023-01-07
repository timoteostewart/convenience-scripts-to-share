#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exitstatus; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

# check for root
if (( ${EUID:-$(id -u)} != 0 )); then
    printf -- "Please run this script as root.\n\n"
    exit 1
fi

die () {
    printf -- "\n*\n* Error: ${1:-Unspecified Error}\n"
    printf -- "* An unrecoverable error has occurred. Look above for any error messages.\n"
    printf -- "* The script '${BASH_SOURCE##*/}' will exit now.\n*\n"
    exit 1
}

die-if-program-not-available () {
    program-not-available "${1}" && die "${2}"
}

program-not-available () {
    program-available "${1}" && return 1
    return 0
}

program-available () {
    command -v "${1}" >/dev/null 2>&1 && return 0
    return 1
}

die-if-file-not-present () {
    [ ! -f "${1}" ] && die "${2}"
}

program_name=nordvpn

temp_dir="/tmp/${program_name}-temp"
rm --recursive --force "${temp_dir}" || die "Couldn't delete the existing '${temp_dir}'"
mkdir -p ${temp_dir} || die "Failed to create temporary directory."
cd ${temp_dir} || die "Failed to change to temporary directory."

# steps below were cribbed from https://downloads.nordcdn.com/apps/linux/install.sh

apt-get update -y
apt-get install -y apt-transport-https

program-not-available curl && apt-get install -y curl
die-if-program-not-available curl "'curl' is required and couldn't be installed."

# add NordVPN's PGP key
curl --fail --location --silent --show-error https://repo.nordvpn.com/gpg/nordvpn_public.asc | tee /etc/apt/trusted.gpg.d/nordvpn_public.asc > /dev/null

# add NordVPN's repo
echo "deb https://repo.nordvpn.com/deb/nordvpn/debian stable main" | tee /etc/apt/sources.list.d/nordvpn.list

# install NordVPN client via apt
apt-get update -y
apt-get install -y nordvpn

usermod -aG nordvpn ${SUDO_USER}

printf -- "Next steps:

sudo shutdown -r now  # required to ensure that 'usermod' changes take effect

nordvpn login --token YOUR_TOKEN_HERE

sudo ufw disable
sudo printf -- "nameserver 8.8.8.8\n" | sudo tee /etc/resolv.conf > /dev/null

nordvpn whitelist add port 22    # SSH
nordvpn whitelist add port 53    # DNS
nordvpn whitelist add port 80    # HTTP
nordvpn whitelist add port 443   # HTTPS, OpenVPN
nordvpn whitelist add port 500   # IPSec, L2TP
nordvpn whitelist add port 1194  # OpenVPN
nordvpn whitelist add port 1701  # L2TP
nordvpn whitelist add port 1723  # PPTP
nordvpn whitelist add port 4500  # IPSec, L2TP

nordvpn set analytics off
nordvpn set autoconnect on
nordvpn set dns 8.8.8.8
nordvpn set firewall on
nordvpn set ipv6 off
nordvpn set killswitch on
nordvpn set meshnet off
nordvpn set notify off
nordvpn set routing on
nordvpn set technology nordlynx
nordvpn set threatprotectionlite off

nordvpn connect

"

