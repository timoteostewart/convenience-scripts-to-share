#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exitstatus; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

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
if program-available gs; then
    GS_BEFORE_VERSION="$(gs --version)"
    GS_BEFORE_HASH="$(sha256sum "$(which gs)")"
    GS_BEFORE_CREATION_DATE="$(stat -c '%w' "$(which gs)")"
else
    GS_BEFORE_VERSION="not_installed"
fi

# install GhostScript from source
program_name=gs
temp_dir="/tmp/${program_name}-temp"
rm --recursive --force "${temp_dir}" || die "Couldn't delete the existing '${temp_dir}'"
mkdir -p ${temp_dir}
cd ${temp_dir} || die "Failed to change to temporary directory."

gs_source_archive=ghostpdl-10.0.0.tar.gz
gs_source_url="https://github.com/ArtifexSoftware/ghostpdl-downloads/releases/download/gs1000/${gs_source_archive}"
curl --remote-name --fail --location --silent --show-error "${gs_source_url}"
die-if-file-not-present "${gs_source_archive}" "Failed to download GhostScript source code archive from github.com."
tar -xzf "${gs_source_archive}"
cd */ || die "Failed to change to GhostScript's source code directory."
./configure || die "Failed to configure GhostScript using './configure'."
make clean || die "Failed to complete 'make clean'."
make || die "Failed to compile GhostScript using 'make'."
make install || die "Failed to install GhostScript using 'make install'."

die-if-program-not-available gs "GhostScript failed to install from source."

printf -- "\n$(gs -v)\n"

GS_AFTER_VERSION="$(gs --version)"
GS_AFTER_HASH="$(sha256sum "$(which gs)")"
GS_AFTER_CREATION_DATE="$(stat -c '%w' "$(which gs)")"

if [ "${GS_BEFORE_VERSION}" == "${GS_AFTER_VERSION}" ]; then
    if [ "${GS_BEFORE_HASH}" == "${GS_AFTER_HASH}" ]; then
        if [ "${GS_BEFORE_CREATION_DATE}" == "${GS_AFTER_CREATION_DATE}" ]; then
            # versions same, hashes same, creation dates same
            printf -- "\n*\n* The current GhostScript version is still %s and the binary's creation date is the same,\n" "${GS_BEFORE_VERSION}"
            printf -- "* so it's possible that GhostScript failed to compile or install, even though no errors were caught.\n*\n"
        else
            # versions same, hashes same, but creation dates different
            printf -- "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
            printf -- "* The previously installed GhostScript version was also %s, but the binary has been recompiled.\n*\n" "${GS_BEFORE_VERSION}"
        fi
    else
        # versions same, but hashes different
        printf -- "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
        printf -- "* The previously installed GhostScript version was also %s, but the binary has been recompiled.\n*\n" "${GS_BEFORE_VERSION}"
    fi    
else
    if [ "${GS_BEFORE_VERSION}" == "not_installed" ]; then
        # versions different, wasn't installed before
        printf -- "\n*\n* GhostScript version %s was successfully installed from source.\n*\n" "${GS_AFTER_VERSION}"
    else
        # versions different, was installed before
        printf -- "\n*\n* GhostScript version %s was successfully installed from source.\n" "${GS_AFTER_VERSION}"
        printf -- "* The previously installed GhostScript version was %s.\n*\n" "${GS_BEFORE_VERSION}"
    fi
fi

exit 0

