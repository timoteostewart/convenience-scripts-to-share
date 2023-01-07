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
    rm --recursive --force "${libwebp_temp_dir}"
    rm --recursive --force "${imagemagick_temp_dir}"
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
die-if-program-not-available apt-get "This script requires the APT dependency management system."
die-if-program-not-available perl "This script requires Perl for multiline 'sed'."

apt-get update

# preliminaries
if program-available magick; then
    MAGICK_BEFORE_VERSION="$(printf --  "$(printf -- "$(printf -- "$(magick -version)" | perl -p -e 's/\n/\ /')" | perl -p -e 's/Version:\ ImageMagick\ //')" | perl -p -e 's/\ .*//')"
    MAGICK_BEFORE_HASH="$(sha256sum "$(which magick)" | sed "s/\ .*//")"
    MAGICK_BEFORE_CREATION_DATE="$(stat -c '%w' "$(which magick)")"
else
    MAGICK_BEFORE_VERSION="not_installed"
fi

#
# the script broadly follows the instructions at: https://imagemagick.org/script/install-source.php
#

# check if a compiler is installed since we'll be compiling `libwebp` and `imagemagick` from source
if program-not-available gcc; then
    printf -- "No C compiler detected. Will try to install 'gcc'..."
    apt-get install -y build-essential
    die-if-program-not-available gcc "Failed to install dependency 'gcc'."
    printf -- "'gcc' successfully installed."
fi

# install xmlstarlet, which we'll use later when verifying the archive's integrity
if ! apt-get install -y xmlstarlet; then
    die "Failed to install dependency 'xmlstarlet'."
fi
die-if-program-not-available xmlstarlet "Dependency 'xmlstarlet' didn't install correctly."

# install packages needed by libwebp
apt-get install -y libjpeg-dev libpng-dev libtiff-dev libgif-dev

# install libwebp from source
libwebp_temp_dir=/tmp/libwebp-install
rm --recursive --force "${libwebp_temp_dir}" || die "Couldn't delete the existing '${libwebp_temp_dir}'"
mkdir ${libwebp_temp_dir}
cd ${libwebp_temp_dir} || die "Failed to change to temporary directory."
libwebp_archive=libwebp-1.2.4.tar.gz
curl --remote-name --fail --location --silent --show-error "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/${libwebp_archive}"
die-if-file-not-present "${libwebp_archive}" "Failed to download webp source code archive from googleapis.com."
tar -xzf "${libwebp_archive}"
cd */ || die "Failed to change to libwebp's source code directory."
./configure || die "Failed to configure libwebp using './configure'."
make clean || die "Failed to complete 'make clean'."
make || die "Failed to compile libwebp using 'make'."
make install || die "Failed to install libwebp using 'make install'."
export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
export LD_RUN_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/

# prepare our ImageMagick installation environment
imagemagick_temp_dir=/tmp/imagemagick-install
rm --recursive --force "${imagemagick_temp_dir}" || die "Couldn't delete the existing '${imagemagick_temp_dir}'"
mkdir "${imagemagick_temp_dir}"
cd "${imagemagick_temp_dir}" || die "Failed to change to temporary directory."

# download ImageMagick archive and hash digest and verify the archive's integrity
imagemagick_archive=ImageMagick.tar.gz
curl --remote-name --fail --location --silent --show-error "https://imagemagick.org/archive/${imagemagick_archive}"
die-if-file-not-present "${imagemagick_archive}" "Failed to download ImageMagick source code archive from imagemagick.org."

curl --remote-name --fail --location --silent --show-error "https://imagemagick.org/archive/digest.rdf"
die-if-file-not-present "digest.rdf" "Failed to download the message digest containing the SHA256 hashes that verify source code integrity."
hash_from_digest=$(xmlstarlet sel -t -v "//digest:Content[contains(@rdf:about, \"${imagemagick_archive}\")]/digest:sha256" "digest.rdf")
if [ -z "${hash_from_digest}" ]; then
    die "Failed to extract hash from message digest."
fi
hash_from_file=$(sha256sum "${imagemagick_archive}" | sed "s/\ .*//")
[ "${hash_from_digest}" != "${hash_from_file}" ] && die "Hashes for archive and digest don't match."

# proceed with ImageMagick installation
tar -xzf "${imagemagick_archive}"
cd */ || die "Failed to change to ImageMagick's source code directory."
./configure --enable-delegate-build --enable-shared --with-jxl || die "Failed to configure ImageMagick using './configure'."
make clean || die "Failed to complete 'make clean'."
make || die "Failed to compile ImageMagick using 'make'."
make install || die "Failed to install ImageMagick using 'make install'."
ldconfig /usr/local/lib

die-if-program-not-available magick "ImageMagick failed to install from source."

magick identify -list format
magick identify -list policy

printf -- "\n$(magick --version)\n"

MAGICK_AFTER_VERSION="$(printf --  "$(printf -- "$(printf -- "$(magick -version)" | perl -p -e 's/\n/\ /')" | perl -p -e 's/Version:\ ImageMagick\ //')" | perl -p -e 's/\ .*//')"
MAGICK_AFTER_HASH="$(sha256sum "$(which magick)" | sed "s/\ .*//")"
MAGICK_AFTER_CREATION_DATE="$(stat -c '%w' "$(which magick)")"

if [ "${MAGICK_BEFORE_VERSION}" == "${MAGICK_AFTER_VERSION}" ]; then
    if [ "${MAGICK_BEFORE_HASH}" == "${MAGICK_AFTER_HASH}" ]; then
        if [ "${MAGICK_BEFORE_CREATION_DATE}" == "${MAGICK_AFTER_CREATION_DATE}" ]; then
            # versions same, hashes same, creation dates same
            printf -- "\n*\n* The current ImageMagick version is still %s and the binary's creation date is the same,\n" "${MAGICK_BEFORE_VERSION}"
            printf -- "* so it's possible that ImageMagick failed to compile or install, even though no errors were caught.\n*\n"
        else
            # versions same, hashes same, but creation dates different
            printf -- "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
            printf -- "* The previously installed ImageMagick version was also %s, but the binary has been recompiled.\n*\n" "${MAGICK_BEFORE_VERSION}"
        fi
    else
        # versions same, but hashes different
        printf -- "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
        printf -- "* The previously installed ImageMagick version was also %s, but the binary has been recompiled.\n*\n" "${MAGICK_BEFORE_VERSION}"
    fi    
else
    if [ "${MAGICK_BEFORE_VERSION}" == "not_installed" ]; then
        # versions different, and wasn't installed before
        printf -- "\n*\n* ImageMagick version %s was successfully installed from source.\n*\n" "${MAGICK_AFTER_VERSION}"
    else
        # versions different, and was installed before
        printf -- "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
        printf -- "* The previously installed ImageMagick version was %s.\n*\n" "${MAGICK_BEFORE_VERSION}"
    fi
fi

# create ImageMagick policy.xml
cat <<'POLICY_XML' > "/usr/local/etc/ImageMagick-7/policy.xml"
<policymap>
    <policy domain="resource" name="area" value="999MP"/>
    <policy domain="resource" name="disk" value="8GiB"/>
    <policy domain="resource" name="file" value="768"/>
    <policy domain="resource" name="height" value="999KP"/>
    <policy domain="resource" name="map" value="4GiB"/>
    <policy domain="resource" name="memory" value="4GiB"/>
    <policy domain="resource" name="temporary-path" value="/tmp"/>
    <policy domain="resource" name="thread" value="16"/>
    <policy domain="resource" name="throttle" value="0"/>
    <policy domain="resource" name="width" value="999KP"/>
</policymap>

POLICY_XML

[ ! -f "/usr/local/etc/ImageMagick-7/policy.xml" ] && printf -- "\n*\n* Warning: couldn't create /usr/local/etc/ImageMagick-7/policy.xml\n*\n."

exit 0
