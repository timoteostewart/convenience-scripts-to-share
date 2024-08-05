#!/usr/bin/env bash

# debugging switches
# set -o errexit  # abort on nonzero exit status; same as set -e
# set -o nounset  # abort on unbound variable; same as set -u
# set -o pipefail # don't hide errors within pipes
# set -o xtrace   # show commands being executed; same as set -x
# set -o verbose  # verbose mode; same as set -v

# usage: add-deb-repo $KEY_URL $REPO_URL $DISTRO $COMPONENT $LABEL
# returns: none, but adds a new Debian repository
add-deb-repo() {
    # Check for missing parameters
    [[ -z "${1}" ]] && die "add-deb-repo() requires a key_url to be specified."
    [[ -z "${2}" ]] && die "add-deb-repo() requires a repo_url to be specified."
    [[ -z "${3}" ]] && die "add-deb-repo() requires a distro to be specified."
    [[ -z "${4}" ]] && die "add-deb-repo() requires a component to be specified."
    [[ -z "${5}" ]] && die "add-deb-repo() requires a label to be specified."

    local key_rings_root="/usr/share/keyrings/"
    local sources_root="/etc/apt/sources.list.d/"

    if [[ ! -d "${key_rings_root}" ]]; then
        install -m 0644 -d "${key_rings_root}" || die "Failed to setup ${key_rings_root}."
    fi

    dependencies_to_install=(
        curl
        gnupg2
    )
    install_apt_packages "${dependencies_to_install[@]}"

    local key_url="${1}"
    local repo_url="${2}"
    local distro="${3}"
    local component="${4}"
    local label="${5}"
    local keyring_file="${key_rings_root}${label}-keyring.gpg"
    local sources_list_file="${sources_root}${label}.list"

    temp_file=$(mktemp)
    curl --fail --location --output "${temp_file}" --silent --show-error --url "${key_url}"
    [[ ! -f "${temp_file}" ]] && die "Failed to download ${label} GPG key."

    # now we must check wether as have an ASCII armored key or a binary key
    grep_result=$(grep -oP "\-\-\-\-\-BEGIN\ PGP\ PUBLIC\ KEY\ BLOCK\-\-\-\-\-" "${temp_file}")

    if [[ -z "${grep_result}" ]]; then
        die "Failed to read the downloaded ${label} GPG key."
    fi

    if [[ "${grep_result}" == "-----BEGIN PGP PUBLIC KEY BLOCK-----" ]]; then
        if gpg --show-keys "${temp_file}" >/dev/null 2>/dev/null; then
            key_file_type="asc"
        else
            die "Unknown key file type for ${key_url}"
        fi
    else
        if gpg --show-keys "${temp_file}" >/dev/null 2>/dev/null; then
            key_file_type="gpg"
        else
            die "Unknown key file type for ${key_url}"
        fi
    fi

    [[ "${key_file_type}" == "asc" ]] && gpg --dearmor --yes --output "${keyring_file}" "${temp_file}"
    [[ "${key_file_type}" == "gpg" ]] && mv "${temp_file}" "${keyring_file}"

    [[ ! -f "${keyring_file}" ]] && die "Failed to install ${label} GPG key."

    chmod 0644 "${keyring_file}"

    printf "deb [arch=$(dpkg --print-architecture) signed-by=${keyring_file}] ${repo_url} ${distro} ${component}\n" | tee --append "${sources_list_file}" >/dev/null

    [[ ! -f "${sources_list_file}" ]] && die "Failed to add ${label} repository to APT sources."

}

# usage: am-root
# returns: 0 if root, 1 if not root
am-root() {
    local EUID_copy="${EUID:-$(id -u)}"
    [[ -z "${EUID_copy}" ]] && die "am-root() could not determine the current user's EUID."
    ((EUID_copy == 0))
}

# usage: cd-or-die $DIRECTORY
# returns: none, but changes to the specified directory or exits with an error
cd-or-die() {
    [[ -z "${1}" ]] && die "cd-or-die() requires a directory to be specified."
    [[ ! -d "${1}" ]] && die "The path ${1} is not a directory."
    cd "${1}" || die "Could not cd to ${1}."
}

# usage: convert-time-in-unix-seconds-to-iso8601 $UNIX_TIME
# returns: formatted ISO8601 date string based on provided Unix time
convert-time-in-unix-seconds-to-iso8601() {
    local unix_time="${1}"
    [[ -z "${unix_time}" ]] && die "convert-time-in-unix-seconds-to-iso8601() requires a Unix time to be specified."
    date --utc +"%Y-%m-%dT%H:%M:%SZ" --date="@${unix_time}"
}

# usage: count-network-interfaces
# returns: the number of network interfaces, excluding the loopback interface
count-network-interfaces() {
    local broadcast_interfaces
    mapfile -t broadcast_interfaces < <(get-list-of-network-interfaces)
    printf '%d' "${#broadcast_interfaces[@]}"
}

# usage: die "$MESSAGE" ["$EXIT_CODE"]
# returns: nothing, exits with provided or default exit code
die() {
    local message="${1:-Unspecified Error}"
    local exit_code="${2:-1}"
    printf >&2 "Error: %s\nAn unrecoverable error has occurred. Look above for any error messages.\n" "${message}"
    exit "${exit_code}"
}

# usage: die-if-file-not-present $FILENAME_WITH_PATH ["$MESSAGE"]
# returns: nothing, exits with error message if file not found
die-if-file-not-present() {
    [[ -z "${1}" ]] && die "die-if-file-not-present() requires a filename to be specified."
    local filename="${1}"
    local message="${2:-File ${filename} not found.}"
    [[ -f "${filename}" ]] || die "${message}"
}

# usage: die-if-not-root
# returns: nothing, exits with error message if not run as root
die-if-not-root() {
    am-root || die "Please run this script as root (e.g., using ‘sudo’)."
}

# usage: die-if-root
# returns: nothing, exits with error message if run as root
die-if-root() {
    am-root && die "Please run this script as a non-root user (e.g., not as root, not using ‘sudo’)."
}

# usage: die-if-program-not-available $PROGRAM_NAME "$MESSAGE"
# returns: nothing, exits with error message if program not available
die-if-program-not-available() {
    program-not-available "${1}" && die "${2}"
    return 0
}

# usage: ensure-dir-or-die $DIRECTORY
# returns: none, but creates the specified directory or exits with an error
ensure-dir-or-die() {
    [[ -z "${1}" ]] && die "ensure-dir-or-die() requires a directory to be specified."
    local dir="${1}"
    mkdir --parents "$dir" || die "Could not create directory ${dir}."
}

# usage: ensure-file-or-die $FILE
# returns: none, but creates the specified file or exits with an error
ensure-file-or-die() {
    [[ -z "${1}" ]] && die "ensure-file-or-die() requires a file to be specified."
    local file="${1}"
    touch "${file}" || die "Could not create file ${file}."
}

# usage: get-ip-address-for-interface $INTERFACE
# returns: IP address for the specified network interface
get-ip-address-for-interface() {
    local interface="${1}"
    [[ -z "${interface}" ]] && die "get-ip-address-for-interface() requires an interface name to be specified."
    ip_address=$(ip -4 address show "${interface}" | grep --perl-regexp --only-matching "(?<=inet\s)\d+\.\d+\.\d+\.\d+" | head --lines=1)
    [[ -z "${ip_address}" ]] && die "get-ip-address-for-interface() could not determine the IP address for the interface ${interface}."
    printf "${ip_address}"
}

# usage: get-iso8601-date
# returns: current date and time in ISO8601 format
get-iso8601-date() {
    printf "$(date --utc +"%Y-%m-%dT%H:%M:%SZ")"
}

# usage: get-iso8601-date-microseconds
# returns: current date and time in ISO8601 format with microsecond precision
get-iso8601-date-microseconds() {
    printf "$(date --utc +"%Y-%m-%dT%H:%M:%S.%6NZ")"
}

# usage: get-iso8601-date-milliseconds
# returns: current date and time in ISO8601 format with millisecond precision
get-iso8601-date-milliseconds() {
    printf "$(date --utc +"%Y-%m-%dT%H:%M:%S.%3NZ")"
}

# usage: get-list-of-network-interfaces
# returns: list of active network interfaces excluding loopback
get-list-of-network-interfaces() {
    local interfaces
    mapfile -t interfaces < <(ip link show | awk '/: <BROADCAST,/{gsub(/:$/, "", $2); print $2}' | sed 's/@.*//')
    printf '%s' "${interfaces[@]}"
}

# usage: get-name-of-default-interface
# returns: name of the default network interface
get-name-of-default-interface() {
    default_interface=$(ip route show default | awk '/default/ {print $5}')
    printf "${default_interface}"
}

# usage: get-time-in-unix-seconds
# returns: current time in Unix seconds
get-time-in-unix-seconds() {
    printf "$(date --utc +%s)"
}

install_apt_packages() {
    local packages=("$@")
    for package in "${packages[@]}"; do
        apt-get -y install "${package}" || die "Failed to install package \`${package}\`."
    done
}

# usage: is-ufw-active
# returns: 0 if UFW is active, 1 if inactive, exits with error for unexpected output
is-ufw-active() {

    die-if-not-root

    output=$(ufw status | head -n 1)
    if [[ "${output}" == "Status: active" ]]; then
        return 0
    elif [[ "${output}" == "Status: inactive" ]]; then
        return 1
    else
        die "Unexpected output from ufw status."
    fi

}

# usage: make-beep
# returns: none, but produces a system beep
make-beep() {
    printf "\a"
}

# usage: prefer $INTERFACE_NAME
# example: prefer eth0
# returns: 0 if successful, 1 if not successful
prefer() {

    die-if-not-root

    preferred_network_name="${1}"

    if [[ -z "${preferred_network_name}" ]]; then
        printf "Argument must be eth0 or eth1.\n"
        exit 1
    fi

    if [[ "$1" != "eth0" ]] && [[ "$1" != "eth1" ]]; then
        printf "Argument must be eth0 or eth1.\n"
        exit 1
    fi

    is-ip-address-reachable() {
        local ip_address="${1}"
        if ping -c 4 -q "${ip_address}" >/dev/null; then
            return 0
        else
            return 1
        fi
    }

    update-metric-for-interface() {
        local gateway_address="${1}"
        local interface_name="${2}"
        local metric="${3}"
        ip route del default via "${gateway_address}" dev "${interface_name}"
        ip route add default via "${gateway_address}" dev "${interface_name}" metric "${metric}"
    }

    make_preferred() {
        local primary_interface="${1}"

        if [[ "${primary_interface}" == "eth0" ]]; then
            local primary_gateway="192.168.1.1"
            local secondary_interface="eth1"
            local secondary_gateway="192.168.2.254"
        fi
        if [[ "${primary_interface}" == "eth1" ]]; then
            local primary_gateway="192.168.2.254"
            local secondary_interface="eth0"
            local secondary_gateway="192.168.1.1"
        fi

        update-metric-for-interface "${primary_gateway}" "${primary_interface}" 1000
        # higher number means lower priority
        update-metric-for-interface "${secondary_gateway}" "${secondary_interface}" 1024

    }

    # Define an array of IP addresses
    ip_addresses=("192.168.1.1" "192.168.2.254")

    # Loop through each IP address in the array
    for ip in "${ip_addresses[@]}"; do
        if ! is-ip-address-reachable "${ip}"; then
            printf "%s not reachable!\n" "${ip}"
            exit 1
        fi
    done

    sleep 4

    make_preferred "${preferred_network_name}"

    wan_ip=$(curl --silent icanhazip.com)
    printf "preferred interface: ${preferred_network_name}\n"
    printf "wan_ip=${wan_ip}\n"
}

# usage: prettify-duration-seconds $TOTAL_SECONDS
# returns: a human-readable string representing the duration
prettify-duration-seconds() {
    local total_seconds=${1}
    local weeks=$((total_seconds / 604800))
    local days=$((total_seconds % 604800 / 86400))
    local hours=$((total_seconds % 86400 / 3600))
    local minutes=$((total_seconds % 3600 / 60))
    local seconds=$((total_seconds % 60))

    local result=""
    [[ ${weeks} -gt 0 ]] && result+="${weeks} weeks "
    [[ ${days} -gt 0 ]] && result+="${days} days "
    [[ ${hours} -gt 0 ]] && result+="${hours} hours "
    [[ ${minutes} -gt 0 ]] && result+="${minutes} minutes "
    [[ ${seconds} -gt 0 ]] && result+="${seconds} seconds "

    printf "${result}"
}

# usage: program-not-available $PROGRAM_NAME
# returns: 0 if program isn't available, 1 if program is available
program-not-available() {
    [[ -z "${1}" ]] && die "program-not-available() requires a program to be specified."
    program-available "${1}" && return 1
    return 0
}

# usage: program-available $PROGRAM_NAME
# returns: 0 if the program is available, 1 otherwise.
program-available() {
    [[ -z "${1}" ]] && die "program-available() requires a program to be specified."
    command -v "${1}" >/dev/null 2>&1 || return 1
    return 0
}

purge_apt_packages() {
    local packages=("$@")
    for package in "${packages[@]}"; do
        apt-get -y purge "${package}" || die "Failed to purge package \`${package}\`."
    done
}

# usage: source-if-exists $FILE
# returns: sources the file if it exists, prints error and returns 1 if it doesn't
source-if-exists() {
    local file=$1
    if [[ -f "${file}" ]]; then
        # shellcheck disable=SC1090
        source "${file}"
    else
        printf >&2 "Error: Could not find '%s'.\n" "$file"
        return 1
    fi
}

# usage: trim_string $STRING
# returns: trimmed string with leading and trailing whitespace removed
trim_string() {
    local input=$1
    # Remove leading whitespace
    input="${input#"${input%%[![:space:]]*}"}"
    # Remove trailing whitespace
    input="${input%"${input##*[![:space:]]}"}"
    printf "${input}"
}
