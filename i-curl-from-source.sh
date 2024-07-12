#!/usr/bin/env bash

# debugging switches
# set -o errexit  # abort on nonzero exit status; same as set -e
# set -o nounset  # abort on unbound variable; same as set -u
# set -o pipefail # don't hide errors within pipes
# set -o xtrace   # show commands being executed; same as set -x
# set -o verbose  # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

apt-get -y update && apt-get -y upgrade

TEMP_DIR=$(mktemp --directory)
cd-or-die "${TEMP_DIR}"

if program-not-available curl; then
    apt-get -y install curl
fi

die-if-program-not-available curl "An existing \`curl\` isn't available, so the script can't determine where to install a new \`curl\`."

# find where curl lives, so we can install new curl using the same directory path prefix
CUR_CURL_PATH=$(which curl)
PREFIX_FOR_MAKE=$(printf "%s" "${CUR_CURL_PATH}" | sed "s,/[^/]*$,," | sed "s,/[^/]*$,,")

# get latest stable version of curl
LATEST_VER=$(curl --silent https://curl.se/changes.html | grep --max-count 1 --only-matching --perl-regexp "(?<=<h2> Fixed in ).*?(?= -.*)")
ARCHIVE_BASENAME="curl-${LATEST_VER}"
curl --location --show-error --silent --url "https://curl.se/download/${ARCHIVE_BASENAME}.tar.gz" --output "${TEMP_DIR}/${ARCHIVE_BASENAME}.tar.gz"

# remove existing curl, so we can install a new one
apt-get -y purge curl

if ! tar -xzvf "${ARCHIVE_BASENAME}.tar.gz"; then
    die "Couldn't extract source code via \`tar\`."
fi

# install dependencies for build
apt-get -y install build-essential
apt-get -y install libbrotli1 libbrotli-dev
apt-get -y install libssh2-1 libssh2-1-dev
apt-get -y install libzstd1 libzstd-dev

cd-or-die "${ARCHIVE_BASENAME}"

# `--with-ngtcp2` omitted from next line since it requires QUIC-compatible TLS
if ! ./configure --enable-websockets --prefix="${PREFIX_FOR_MAKE}" --with-brotli --with-libssh2 --with-nghttp2 --with-openssl --with-zstd; then
    die "\`configure\` failed."
fi

if ! make; then
    die "\`make\` failed."
fi

if ! make install; then
    die "\`make install\` failed."
fi

die-if-program-not-available curl "Building \`curl\` seemed to work, but \`curl\` can't be located."
