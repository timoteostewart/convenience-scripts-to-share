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

# apt install -y software-properties-common
# add-apt-repository ppa:deadsnakes/ppa

if ! apt-get install -y python3.11; then
    die "Error: python 3.11 failed to install."
fi

## don't do the following unless you can also: `cd /usr/lib/python3/dist-packages/ && cp ./apt_pkg.cpython-311-x86_64-linux-gnu.so ./apt_pkg.so`
# rm /usr/bin/python
# rm /usr/bin/python3
# ln -s /usr/bin/python3.11 /usr/bin/python
# ln -s /usr/bin/python3.11 /usr/bin/python3

die-if-program-not-available python3.11 "Error: python 3.11 seemed to install, but it's not showing up."

if ! apt-get install -y python3-pip; then
    die "Error: pip3 failed to install."
fi

die-if-program-not-available pip3 "Error: pip3 seemed to install, but it's not showing up."

if ! apt-get install -y python3.11-venv; then
    die "Error: python3.11-venv failed to install."
fi

printf -- "\nSuccessfully installed Python 3.11 and pip3.\n"

