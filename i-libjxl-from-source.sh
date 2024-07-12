#!/usr/bin/env bash

# debugging switches
set -o errexit # abort on nonzero exit status; same as set -e
# set -o nounset  # abort on unbound variable; same as set -u
set -o pipefail # don't hide errors within pipes
# set -o xtrace   # show commands being executed; same as set -x
# set -o verbose # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

apt-get -y update
apt-get -y install build-essential clang cmake git libc++-dev libc++abi-dev pkg-config
apt-get -y install libbrotli-dev libgif-dev libjpeg-dev libopenexr-dev libpng-dev libwebp-dev

# save current environment variables before setting them to build with clang
cur_cc="${CC}"
cur_cxx="${CXX}"

export CC=clang
export CXX=clang++

reset_env_vars() {
    if [ -n "${cur_cc}" ]; then
        export CC="${cur_cc}"
    else
        unset CC
    fi

    if [ -n "${cur_cxx}" ]; then
        export CXX="${cur_cxx}"
    else
        unset CXX
    fi
}

trap reset_env_vars EXIT
trap reset_env_vars ERR

# prepare our ImageMagick installation environment
libjxl_temp_dir=$(mktemp --directory)
cd ${libjxl_temp_dir} || die "Failed to change to temporary directory."
git clone https://github.com/libjxl/libjxl.git --recursive --shallow-submodules || die "Failed to clone libjxl's source code repository."

prefix_dir=/usr/local/

cd-or-die libjxl
mkdir --parents build
cd-or-die build
cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX="${prefix_dir}" -DBUILD_TESTING=OFF -DCMAKE_CXX_FLAGS="-stdlib=libc++" -DCMAKE_EXE_LINKER_FLAGS="-stdlib=libc++" -DCMAKE_SHARED_LINKER_FLAGS="-stdlib=libc++" ..

cmake --build . -- -j$(nproc)
cmake --install .

printf "libjxl temp dir =    ${libjxl_temp_dir}\n"
printf "libjxl install dir = ${prefix_dir}\n"
