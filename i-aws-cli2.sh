#!/usr/bin/env bash

# check for root
if (( ${EUID:-$(id -u)} != 0 )); then
    printf -- "Please run this script as root.\n"
    exit 1
fi

die () {
    printf -- "\n*\n* Error: %s\n" "${1:-Unspecified Error}"
    printf -- "* An unrecoverable error has occurred. Look above for any error messages.\n"
    printf -- "* The script '%s' will exit now.\n*\n" "${BASH_SOURCE##*/}"
    exit 1
}

apt update || die "Failed to `apt update`"
apt install -y unzip || die "Failed to `apt install -y unzip`"

cd /tmp || die "Failed to `cd /tmp`"

cur_arch=$(dpkg --print-architecture)

if [[ -z ${cur_arch} ]]; then
    die "Failed to `dpkg --print-architecture`"
fi

if [[ ${cur_arch} == "amd64" ]]; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
elif [[ ${cur_arch} == "arm64" ]] || [[ ${cur_arch} == "aarch64" ]]; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" -o "awscliv2.zip"
else
    die "Could not detect current system's CPU architecture."
fi

unzip awscliv2.zip || die "Failed to `unzip awscliv2.zip`"

./aws/install || die "Failed to `./aws/install`"

aws --version || die "Installation seemed successfully, but failed to `aws --version`"

printf -- "Installation seems successful."

