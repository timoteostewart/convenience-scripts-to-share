#!/usr/bin/env bash

# check for root
if [[ $(id -u) != 0 ]]; then
    echo "Please run this script as root."
    exit 1
fi

die () {
    printf -- "\n*\n* Error: %s\n" "${1:-Unspecified Error}"
    printf -- "* An unrecoverable error has occurred. Look above for any error messages.\n"
    printf -- "* The script '%s' will exit now.\n*\n" "${BASH_SOURCE##*/}"
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

apt-get update -y

if ! apt-get install -y python3; then
    die "Error: python 3 failed to install."
fi

die-if-program-not-available python3 "Error: python3 seemed to install, but it's not showing up."

if ! apt-get install -y python3-pip; then
    die "Error: pip3 failed to install."
fi

die-if-program-not-available pip3 "Error: pip3 seemed to install, but it's not showing up."

if ! apt-get install -y python3-venv; then
    die "Error: python3-venv failed to install."
fi

printf -- "\nSuccessfully installed Python 3 and pip3.\n"



