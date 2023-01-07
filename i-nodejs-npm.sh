#!/usr/bin/env bash

install_script_url=https://deb.nodesource.com/setup_18.x

print_usage () {
    echo -e "Note: Please review the script at ${install_script_url}, because it will be invoked."
    echo -e "Usage:   sudo ./i-nodejs-npm.sh -v REVIEW_INDICATOR"
    echo -e "Example: sudo ./i-nodejs-npm.sh -v yes"
}

die () {
    echo -e "\n*\n $1"
    echo -e "* An unrecoverable error has occurred. Look above for any error messages."
    echo -e "* The script \`${BASH_SOURCE##*/}\` will exit now.\n*\n"
    exit 1
}

# check for root
if [[ $(id -u) != 0 ]] ; then
    echo "Please run this script as root."
    exit 1
fi

# check for command-line arguments
while getopts "v:" flag
do
    case "${flag}" in
        v) VERIFIED=${OPTARG} ;;
        *) echo "Invalid argument."
           print_usage
           exit 1 ;;
    esac
done

if [[ -z "${VERIFIED}" ]]; then
    echo "Please indicate if you have reviewed the online script."
    print_usage
    exit 1
fi

shopt -s nocasematch
if [[ "$VERIFIED" != "yes" ]]; then
    echo "Please provide the argument \`-v yes\` if you have reviewed the online script."
    print_usage
    exit 1
fi
shopt -u nocasematch

apt update
apt upgrade -y

curl -fsSL ${install_script_url} | sudo -E bash -

apt upgrade -y
# apt install -y gcc g++ make
apt install -y nodejs

# try to update npm
npm update -g npm

# install yarn
curl -sL https://dl.yarnpkg.com/debian/pubkey.gpg | gpg --dearmor | sudo tee /usr/share/keyrings/yarnkey.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/yarnkey.gpg] https://dl.yarnpkg.com/debian stable main" | sudo tee /etc/apt/sources.list.d/yarn.list
apt update && apt install -y yarn

echo -e "Output of \`node --version\`: $(node --version)"
echo -e "Output of \`npm --version\`:  $(npm --version)"
echo -e "Output of \`yarn --version\`:  $(yarn --version)"

exit 0

################################################################################
################################################################################

# Next steps:

see nextjs-notes.txt
