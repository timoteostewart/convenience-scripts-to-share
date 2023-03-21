#!/usr/bin/env bash

# usage: die "$MESSAGE"
die() {
    >&2 printf "\n*\n* Error: ${1:-Unspecified error.}\n* This error is unrecoverable. Check above for additional error messages.\n*\n\n"
    exit 1
}

# usage: am-root
# returns 0 if root, 1 if not root
am-root() {
    if (( ${EUID:-$(id -u)} != 0 )); then
        return 1
    else
        return 0
    fi
}

# usage: die-if-not-root
die-if-not-root() {
    if ! am-root; then
        die "Please run this script as root (e.g., using ‘sudo’)."
        exit 1
    fi
}

# usage: die-if-root
die-if-root() {
    if am-root; then
        die "Please run this script as a non-root user (e.g., not as root, not using ‘sudo’)."
        exit 1
    fi
}


# usage: die-if-program-not-available $PROGRAM_NAME "$MESSAGE"
die-if-program-not-available() {
    program-not-available "${1}" && die "${2}"
}

# usage: program-not-available $PROGRAM_NAME
# returns 0 if program isn't available, 1 if program is available
program-not-available() {
    program-available "${1}" && return 1
    return 0
}

# usage: program-available $PROGRAM_NAME
# returns 0 if program is available, 1 if program isn't available
program-available() {
    command -v "${1}" >/dev/null 2>&1 && return 0
    return 1
}

# usage: die-if-file-not-present $FILENAME_WITH_PATH "$MESSAGE"
die-if-file-not-present() {
    [ ! -f "${1}" ] && die "${2}"
}

