#!/usr/bin/env bash

# debugging switches
# set -o errexit   # abort on nonzero exitstatus; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

source ./functions.sh

die-if-not-root

container_id=$1
template_name=$2

[[ -z "${container_id}" ]] && die "You must provide a container ID as the first argument."
[[ -z "${template_name}" ]] && die "You must provide a name for the resulting template as the second argument."

compression_to_use=zstd
[[ "${compression_to_use}" == "zstd" ]] && compression_file_extension=".tar.zst"
[[ "${compression_to_use}" == "gzip" ]] && compression_file_extension=".tar.gz"
[[ -z "${compression_file_extension}" ]] && die "Invalid or unknown compression type: ${compression_to_use}"

# first, confirm we're using sudo
if ! pct list >/dev/null; then
    die "You must run this script using sudo (even if you are currently root)."
fi

# second, confirm the container exists
pct_list_output=$(pct list | grep -oP "^${container_id}(?= )")
[[ -z "${pct_list_output}" ]] && die "Container ${container_id} does not exist."

# third, confirm the container is running
pct_status_output=$(pct status "${container_id}")
[[ "${pct_status_output}" != *"status: running"* ]] && die "Container ${container_id} is not running. Please rerun script with container ${container_id} running."

# perform pre-decustomization backup
vzdump "${container_id}" --compress "${compression_to_use}" --storage local --mode snapshot --notes-template "pre-decustomization backup of vmid {{vmid}}" || die "pre-customization vzdump failed."

# perform decustomization
# strip container of specific info:
pct set "${container_id}" --delete hostname
pct set "${container_id}" --delete net0
pct set "${container_id}" --delete net1 # if applicable
pct set "${container_id}" --delete mp0  # if applicable
pct set "${container_id}" --delete mp1  # if applicable

# stop container and confirm when/if it has stopped
pct stop "${container_id}"
checks_left=30
while [[ ${checks_left} -gt 0 ]]; do
    printf "Checking if container %d has stopped yet. Checks left: %d\n" "${container_id}" "${checks_left}"
    sleep 10
    pct_status_output=$(pct status "${container_id}")
    [[ "${pct_status_output}" == *"status: stopped"* ]] && checks_left=0
    ((checks_left -= 1))
done

pct_status_output=$(pct status "${container_id}")
[[ "${pct_status_output}" == *"status: stopped"* ]] || die "Container ${container_id} is still running, so script cannot continue."
printf "Container ${container_id} has stopped.\n"

# perform post-decustomization backup
vzdump_output=$(vzdump "${container_id}" --compress "${compression_to_use}" --storage local --mode snapshot --notes-template "post-decustomization backup of vmid {{vmid}}" || die "post-customization vzdump failed." 2>&1)

dump_path=$(echo "${vzdump_output}" | grep -oP "creating vzdump archive '\K[^']+")
dump_dir=$(dirname "${dump_path}")

mv "${dump_path}" "${dump_dir}/../template/cache/${template_name}${compression_file_extension}" || die "Failed to move backup to template cache."

ls "${dump_dir}/../template/cache/${template_name}${compression_file_extension}" || die "Templatizing somehow failed."

printf "Templatizing was successful.\n"

exit 0

###
