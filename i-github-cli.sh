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

program-available () {
    command -v "${1}" >/dev/null 2>&1 && return 0
    return 1
}

program-not-available () {
    program-available "${1}" && return 1
    return 0
}

program-not-available curl && apt-get update -y && apt-get install -y curl

# get curl's GPG key
curl --fail --location --silent --show-error https://cli.github.com/packages/githubcli-archive-keyring.gpg | tee /usr/share/keyrings/githubcli-archive-keyring.gpg > /dev/null
chmod go+r /usr/share/keyrings/githubcli-archive-keyring.gpg

printf -- "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null

apt-get update -y && apt-get install -y gh

