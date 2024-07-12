#!/usr/bin/env bash

# debugging switches
set -o errexit # abort on nonzero exit status; same as set -e
# set -o nounset  # abort on unbound variable; same as set -u
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # show commands being executed; same as set -x
# set -o verbose  # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

apt-get -y update
apt-get -y install build-essential

prefix_dir=/usr/local/libiconv/

libiconv_temp_dir=$(mktemp --directory "/tmp/libiconv-build-tmp-XXXXXX")
cd ${libiconv_temp_dir} || die "Failed to change to temporary directory."

# see https://directory.fsf.org/wiki/Libiconv for latest url
libiconv_version="1.17"
wget "https://ftp.gnu.org/pub/gnu/libiconv/libiconv-${libiconv_version}.tar.gz"

tar --extract --gunzip --file "${libiconv_temp_dir}/libiconv-${libiconv_version}.tar.gz"
cd */ || die "Failed to change to libiconv's source code directory."

./configure --prefix="${prefix_dir}" || die "Failed to configure libiconv."
make -j$(nproc) || die "Failed to build libiconv."
make install || die "Failed to install libiconv."

printf "libiconv temp dir =    ${libiconv_temp_dir}\n"
printf "libiconv install dir = ${prefix_dir}lib\n"
