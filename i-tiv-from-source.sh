#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exitstatus
# set -o nounset   # abort on unbound variable
# set -o pipefail  # don't hide errors within pipes
# set -xv

# check for root
if (( ${EUID:-$(id -u)} != 0 )); then
    printf -- "Please run this script as root.\n"
    exit 1
fi

function clean_up {
    rm --recursive --force "${temp_dir}"
}
trap clean_up EXIT

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

die-if-file-not-present () {
    [ ! -f "${1}" ] && die "${2}"
}

# preliminaries
die-if-program-not-available git "This script requires git."

apt-get update
if program-not-available magick; then
    printf -- "The build process requires ImageMagick. Attempting to install it..."
    apt-get install -y imagemagick
    die-if-program-not-available magick "Failed to install dependency ImageMagick."
    printf -- "'magick' successfully installed."
fi

#
# the script basically follows the instructions at:
# https://unix.stackexchange.com/questions/35333/what-is-the-fastest-way-to-view-images-from-the-terminal
#

# check if a compiler is installed
if program-not-available gcc; then
    printf -- "No C compiler detected. Will try to install 'gcc'..."
    apt-get install -y build-essential
    die-if-program-not-available gcc "Failed to install dependency 'gcc'."
    printf -- "'gcc' successfully installed."
fi

# prepare our tiv installation environment
program_name=tiv
temp_dir="/tmp/${program_name}-temp"
rm --recursive --force "${temp_dir}" || die "Couldn't delete the existing '${temp_dir}'"
mkdir -p "${temp_dir}" || die "Failed to create temporary directory."

cd "${temp_dir}" || die "Failed to change to temporary directory."
git clone https://github.com/stefanhaustein/TerminalImageViewer.git
cd TerminalImageViewer/src/main/cpp
make
sudo make install

exit 0
