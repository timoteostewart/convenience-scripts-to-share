#!/usr/bin/env bash

# debugging switches
set -o errexit   # abort on nonzero exitstatus; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

# function clean_up {
#     [ -d "${imagemagick_temp_dir}" ] && rm --recursive --force "${imagemagick_temp_dir}"
# }
# trap clean_up ERR

# usual progression of scripts:
# i-libjxl-from-source.sh
# i-ghostscript-from-source.sh
# i-imagemagick6-from-source.sh
# i-imagemagick7-from-source.sh
# i-tiv-from-source.sh

# preliminaries
die-if-program-not-available apt-get "This script requires the APT dependency management system."
die-if-program-not-available perl "This script requires Perl for multiline 'sed'."

apt-get -y update

# preliminaries
if program-available magick; then
    MAGICK_BEFORE_VERSION="$(printf  "$(printf "$(printf "$(magick -version)" | perl -p -e 's/\n/\ /')" | perl -p -e 's/Version:\ ImageMagick\ //')" | perl -p -e 's/\ .*//')"
    MAGICK_BEFORE_HASH="$(sha256sum "$(which magick)" | sed "s/\ .*//")"
    MAGICK_BEFORE_CREATION_DATE="$(stat -c '%w' "$(which magick)")"
else
    MAGICK_BEFORE_VERSION="not_installed"
fi

#
# the script broadly follows the instructions at: https://imagemagick.org/script/install-source.php
#

# check if a compiler is installed
if program-not-available gcc; then
    printf "No C compiler detected. Will try to install 'gcc'...\n"
    apt-get -y install build-essential
    die-if-program-not-available gcc "Failed to install dependency 'gcc'."
    printf "'gcc' successfully installed.\n"
fi

apt-get -y install build-essential git
apt-get -y install fontconfig libavif-dev libde265-dev libdjvulibre-dev libfftw3-dev libfreetype-dev libghc-bzlib-dev libgif-dev libgoogle-perftools-dev libgraphviz-dev libgs-dev libheif-dev libheif1 libjbig-dev libjemalloc-dev libjpeg-dev libjpeg-turbo8 libjpeg-turbo8-dev liblcms2-dev liblqr-1-0-dev libltdl-dev liblzma-dev libopenexr-dev libopenjp2-7-dev libpango1.0-dev libperl-dev libpng-dev libraqm-dev libraw-dev librsvg2-dev libtiff-dev libtiff-dev libunwind-dev libwebp-dev libwmf-dev libxml2 libxml2-dev libzip-dev libzstd-dev libzstd1 zlib1g zlib1g-dev

export LD_LIBRARY_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
export LD_RUN_PATH=${LD_LIBRARY_PATH}:/usr/local/lib/
export PKG_CONFIG_PATH=${PKG_CONFIG_PATH}:/usr/local/lib/pkgconfig

# prepare our ImageMagick installation environment
imagemagick_temp_dir=$(mktemp --directory "/tmp/imagemagick-build-tmp-XXXXXX")
cd "${imagemagick_temp_dir}" || die "Failed to change to temporary directory."
git clone https://github.com/ImageMagick/ImageMagick.git || die "Failed to clone ImageMagick's source code repository."

cd */ || die "Failed to change to ImageMagick's source code directory."

prefix_dir=/usr/local/ImageMagick-7/

./configure --prefix="${prefix_dir}" --disable-dependency-tracking --enable-delegate-build --with-modules --with-bzlib=yes --with-djvu=yes --with-dps=yes --with-fftw=yes --with-flif=yes --with-fontconfig=yes --with-fpx=yes --with-freetype=yes --with-gcc-arch=native --with-gslib=yes --with-gvc=yes --with-heic=yes --with-jbig=yes --with-jemalloc=yes --with-jpeg=yes --with-jxl=yes --with-lcms=yes --with-lqr=yes --with-lzma=yes --with-magick-plus-plus=yes --with-openexr=yes --with-openjp2=yes --with-pango=yes --with-perl=yes --with-png=yes --with-raqm=yes --with-raw=yes --with-rsvg=yes --with-tcmalloc=yes --with-tiff=yes --with-webp=yes --with-wmf=yes --with-x=yes --with-xml=yes --with-zip=yes --with-zlib=yes --with-zstd=yes || die "Failed to configure ImageMagick using './configure'."
make -j$(nproc) || die "Failed to compile ImageMagick using 'make'."
make install || die "Failed to install ImageMagick using 'make install'."
ldconfig /usr/local/lib/

magick_binary="${prefix_dir}/bin/magick"

die-if-program-not-available "${magick_binary}" "ImageMagick failed to install from source."

"${magick_binary}" -list format
"${magick_binary}" -list policy

printf "\n$("${magick_binary}" --version)\n"

MAGICK_AFTER_VERSION="$(printf  "$(printf "$(printf "$("${magick_binary}" -version)" | perl -p -e 's/\n/\ /')" | perl -p -e 's/Version:\ ImageMagick\ //')" | perl -p -e 's/\ .*//')"
MAGICK_AFTER_HASH="$(sha256sum "${magick_binary}" | sed "s/\ .*//")"
MAGICK_AFTER_CREATION_DATE="$(stat -c '%w' "${magick_binary}")"

if [ "${MAGICK_BEFORE_VERSION}" == "${MAGICK_AFTER_VERSION}" ]; then
    if [ "${MAGICK_BEFORE_HASH}" == "${MAGICK_AFTER_HASH}" ]; then
        if [ "${MAGICK_BEFORE_CREATION_DATE}" == "${MAGICK_AFTER_CREATION_DATE}" ]; then
            # versions same, hashes same, creation dates same
            printf "\n*\n* The current ImageMagick version is still %s and the binary's creation date is the same,\n" "${MAGICK_BEFORE_VERSION}"
            printf "* so it's possible that ImageMagick failed to compile or install, even though no errors were caught.\n*\n"
        else
            # versions same, hashes same, but creation dates different
            printf "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
            printf "* The previously installed ImageMagick version was also %s, but the binary has been recompiled.\n*\n" "${MAGICK_BEFORE_VERSION}"
        fi
    else
        # versions same, but hashes different
        printf "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
        printf "* The previously installed ImageMagick version was also %s, but the binary has been recompiled.\n*\n" "${MAGICK_BEFORE_VERSION}"
    fi
else
    if [ "${MAGICK_BEFORE_VERSION}" == "not_installed" ]; then
        # versions different, and wasn't installed before
        printf "\n*\n* ImageMagick version %s was successfully installed from source.\n*\n" "${MAGICK_AFTER_VERSION}"
    else
        # versions different, and was installed before
        printf "\n*\n* ImageMagick version %s was successfully installed from source.\n" "${MAGICK_AFTER_VERSION}"
        printf "* The previously installed ImageMagick version was %s.\n*\n" "${MAGICK_BEFORE_VERSION}"
    fi
fi

# create ImageMagick policy.xml
imagemagick_policy_xml="${prefix_dir}/etc/ImageMagick-7/policy.xml"

cat <<'EOF' > "${imagemagick_policy_xml}"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE policymap [
<!ELEMENT policymap (policy)*>
<!ATTLIST policymap xmlns CDATA #FIXED "">
<!ELEMENT policy EMPTY>
<!ATTLIST policy xmlns CDATA #FIXED "">
<!ATTLIST policy domain NMTOKEN #REQUIRED>
<!ATTLIST policy name NMTOKEN #IMPLIED>
<!ATTLIST policy pattern CDATA #IMPLIED>
<!ATTLIST policy rights NMTOKEN #IMPLIED>
<!ATTLIST policy stealth NMTOKEN #IMPLIED>
<!ATTLIST policy value CDATA #IMPLIED>
]>
<policymap>
    <policy domain="resource" name="area" value="999MP"/>
    <policy domain="resource" name="disk" value="12GiB"/>
    <policy domain="resource" name="file" value="768"/>
    <policy domain="resource" name="height" value="999KP"/>
    <policy domain="resource" name="map" value="12GiB"/>
    <policy domain="resource" name="memory" value="12GiB"/>
    <policy domain="resource" name="temporary-path" value="/tmp"/>
    <policy domain="resource" name="thread" value="24"/>
    <policy domain="resource" name="throttle" value="0"/>
    <policy domain="resource" name="width" value="999KP"/>
</policymap>

EOF

[ ! -f "${imagemagick_policy_xml}" ] && printf "\n*\n* Warning: couldn't create %s\n*\n." "${imagemagick_policy_xml}"

printf "imagemagick_temp_dir = %s\n" "${imagemagick_temp_dir}"
printf "imagemagick bin dir: %s/bin\n" "${prefix_dir}"
printf "imagemagick binary: %s\n" "${magick_binary}"
printf "imagemagick policy.xml: %s\n" "${imagemagick_policy_xml}"

printf "

* Possible next steps:
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/magick
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/animate
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/compare
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/composite
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/conjure
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/convert
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/display
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/identify
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/import
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/magick-script
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/mogrify
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/montage
sudo ln -s ${prefix_dir}/bin/magick /usr/local/bin/stream

"

exit 0
