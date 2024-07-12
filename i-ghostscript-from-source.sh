#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exitstatus; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

catch_interrupt() {
    printf >&2 '\nAborting!\n\n'
    clean_up
    exit 1
}

clean_up() {
    [ -d "${gs_temp_dir}" ] && rm --recursive --force "${gs_temp_dir}"
}

trap "catch_interrupt" SIGHUP SIGINT SIGQUIT SIGABRT SIGTERM
trap "clean_up" EXIT

# preliminaries
if program-available gs; then
    GS_BEFORE_VERSION="$(gs --version)"
    GS_BEFORE_HASH="$(sha256sum "$(which gs)")"
    GS_BEFORE_CREATION_DATE="$(stat -c '%w' "$(which gs)")"
else
    GS_BEFORE_VERSION="not_installed"
fi

# install dependencies
apt-get -y update
apt-get -y install autoconf automake build-essential git
apt-get -y install fontconfig libde265-dev libdjvulibre-dev libfftw3-dev libfreetype-dev libghc-bzlib-dev libgif-dev libgoogle-perftools-dev libgraphviz-dev libgs-dev libheif-dev libheif1 libjbig-dev libjemalloc-dev libjpeg-dev libjpeg-turbo8 libjpeg-turbo8-dev liblcms2-dev liblqr-1-0-dev libltdl-dev liblzma-dev libopenexr-dev libopenjp2-7-dev libpango1.0-dev libperl-dev libpng-dev libraqm-dev libraw-dev librsvg2-dev libtiff-dev libtiff-dev libunwind-dev libwebp-dev libwmf-dev libxml2 libxml2-dev libzip-dev libzstd-dev libzstd1 zlib1g zlib1g-dev

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
export LD_RUN_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig

export CPPFLAGS="-I/usr/include/webp/ ${CPPFLAGS}"
printf "CPPFLAGS: %s\n" "${CPPFLAGS}"

export LDFLAGS="-I/usr/lib/x86_64-linux-gnu/ ${LDFLAGS}"
printf "LDFLAGS: %s\n" "${LDFLAGS}"

prefix_dir=/usr/local/

# install GhostScript from source
gs_temp_dir=$(mktemp --directory)
# gs_temp_dir=/tmp/gs_temp_dir
# mkdir --parents "${gs_temp_dir}" || die "Failed to create temporary directory."
cd ${gs_temp_dir} || die "Failed to change to temporary directory."
git clone https://git.ghostscript.com/ghostpdl.git || die "Failed to clone GhostScript's source code repository."
cd */ || die "Failed to change to GhostScript's source code directory."
sudo ./autogen.sh --disable-option-checking --enable-jbig --enable-webp --enable-zstd --prefix="${prefix_dir}" --with-drivers=BMP,JPEG,PNG,PS,TIFF || die "Failed to run './autogen.sh'."
# ./configure || die "Failed to configure GhostScript using './configure'."
# make clean || die "Failed to complete 'make clean'."
make -j$(nproc) || die "Failed to compile GhostScript using 'make'."
make install || die "Failed to install GhostScript using 'make install'."

die-if-program-not-available gs "GhostScript failed to install from source."

printf "\n$(gs -v)\n"

GS_AFTER_VERSION="$(gs --version)"
GS_AFTER_HASH="$(sha256sum "$(which gs)")"
GS_AFTER_CREATION_DATE="$(stat -c '%w' "$(which gs)")"

if [ "${GS_BEFORE_VERSION}" == "${GS_AFTER_VERSION}" ]; then
    if [ "${GS_BEFORE_HASH}" == "${GS_AFTER_HASH}" ]; then
        if [ "${GS_BEFORE_CREATION_DATE}" == "${GS_AFTER_CREATION_DATE}" ]; then
            # versions same, hashes same, creation dates same
            printf "\n*\n* The current GhostScript version is still %s and the binary's creation date is the same,\n" "${GS_BEFORE_VERSION}"
            printf "* so it's possible that GhostScript failed to compile or install, even though no errors were caught.\n*\n"
        else
            # versions same, hashes same, but creation dates different
            printf "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
            printf "* The previously installed GhostScript version was also %s, but the binary has been recompiled.\n*\n" "${GS_BEFORE_VERSION}"
        fi
    else
        # versions same, but hashes different
        printf "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
        printf "* The previously installed GhostScript version was also %s, but the binary has been recompiled.\n*\n" "${GS_BEFORE_VERSION}"
    fi
else
    if [ "${GS_BEFORE_VERSION}" == "not_installed" ]; then
        # versions different, wasn't installed before
        printf "\n*\n* GhostScript version %s was successfully installed from source.\n*\n" "${GS_AFTER_VERSION}"
    else
        # versions different, was installed before
        printf "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
        printf "* The previously installed GhostScript version was %s.\n*\n" "${GS_BEFORE_VERSION}"
    fi
fi

exit 0
