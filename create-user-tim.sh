#!/usr/bin/env bash

# check for root
if (( ${EUID:-$(id -u)} != 0 )); then
    printf -- "Please run this script as root.\n\n"
    exit 1
fi

print_usage () {
tee <<EOF
Usage: $ sudo ./${BASH_SOURCE##*/} -u USERNAME -p PASSWORD -g GPG_PASSPHRASE [-t TIMEZONE_STRING]
OR
Usage: # ./${BASH_SOURCE##*/} -u USERNAME -p PASSWORD -g GPG_PASSPHRASE [-t TIMEZONE_STRING]
Example: # ./${BASH_SOURCE##*/} -u tim -p hunter2 -g hunter2 -t America/Denver

EOF

}

program-not-available () {
    program-available "${1}" && return 1
    return 0
}

program-available () {
    command -v "${1}" >/dev/null 2>&1 && return 0
    return 1
}

die () {
    printf -- "\n*\n* Error: %s\n" "${1:-Unspecified Error}\n"
    printf -- "* An unrecoverable error has occurred. Look above for any error messages.\n\n"
    printf -- "* The script '%s' will exit now.\n*\n" "${BASH_SOURCE##*/}\n"
    exit 1
}

##
## - create user
## - install git, gh, gpg
## - create GPG key and associate it with git
## - create SSH key
## - pause for user to manually put their new GPG and SSH keys into GitHub
##
## - clone git repo of additional convenience scripts
## - install Python 3
##

# check for command-line arguments
while getopts "u:p:g:t:" flag
do
    case "${flag}" in
        u) USERNAME=${OPTARG} ;;
        p) PASSWORD=${OPTARG} ;;
        g) GPG_PASSPHRASE=${OPTARG} ;;
        t) TIMEZONE=${OPTARG} ;;
        *) printf -- "Unrecognized argument used.\n"
           print_usage
           exit 1 ;;
    esac
done

if [[ -z "${USERNAME}" ]]; then
        printf -- "Error: Please supply a username.\n"
        print_usage
        exit 1
fi
if [[ -z "${PASSWORD}" ]]; then
        printf -- "Error: Please supply a password.\n"
        print_usage
        exit 1
fi
if [[ -z "${GPG_PASSPHRASE}" ]]; then
        printf -- "Error: Please supply a GPG passphrase.\n"
        print_usage
        exit 1
fi
if [[ "$USERNAME" == "-p" ]]; then
        printf -- "Error: Please supply a username.\n"
        print_usage
        exit 1
fi
if [[ "$PASSWORD" == "-u" ]]; then
        printf -- "Error: Please supply a password.\n"
        print_usage
        exit 1
fi

# config
export TIM_SYSTEM_USERNAME=${USERNAME}
export TIM_REAL_NAME="Tim Stewart"
export TIM_EMAIL=timoteostewart1977@gmail.com
HOME_DIR=/home/${TIM_SYSTEM_USERNAME}/
CLONE_SCRIPT_NAME=${HOME_DIR}clone-conv-scripts-repo.sh
CONV_SCRIPTS_URL=git@github.com:timoteostewart/conv-scripts.git
CONV_SCRIPTS_REPO_NAME=conv-scripts

# update time zone
if [[ -z "${TIMEZONE}" ]]; then
    timedatectl set-timezone America/Chicago
else
    timedatectl set-timezone "${TIMEZONE}"
fi

# setup UTF-8 locales
locale-gen "en_US.UTF-8"
update-locale "LANG=en_US.UTF-8"
#dpkg-reconfigure --frontend noninteractive locales

# Note: Inside of some Linux containers, use of `sudo` triggers this error:
#   `sudo: setrlimit(RLIMIT_CORE): Operation not permitted`
# For more information, see:
#   https://ryanburnette.com/blog/proxmox-pct-fix-sudo-setrlimit/
#   https://github.com/sudo-project/sudo/issues/42
# Therefore, check whether we're in a container, and if so prevent the
# error message from appearing by modifying /etc/sudo.conf as so:
#   `printf -- "Set disable_coredump false\n" >> /etc/sudo.conf`

mapfile -t RESULT < <(sudo echo 2>&1 > /dev/null)
CONTAINER_CLUE="setrlimit(RLIMIT_CORE): Operation not permitted"
if [[ "${RESULT[0]}" == *"${CONTAINER_CLUE}"*  ]]; then
        # likely in a container
        printf -- "Set disable_coredump false\n" >> /etc/sudo.conf
fi

# turn on ufw
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw --force enable

##
## create user `${TIM_SYSTEM_USERNAME}`
##

# abort if user `${TIM_SYSTEM_USERNAME}` already exists
if id -u "${TIM_SYSTEM_USERNAME}"; then
    die "User '${TIM_SYSTEM_USERNAME}' already exists"
    # printf -- "Aborting script.\n"
    # exit 1
fi
tee <<EOF

*
* Good! That means username '${TIM_SYSTEM_USERNAME}' is available.
*

EOF

ENCRYPTED_PASSWORD=$(openssl passwd -noverify "${PASSWORD}")

useradd --create-home --home-dir "${HOME_DIR}" --groups sudo --password "${ENCRYPTED_PASSWORD}" --shell /bin/bash --user-group "${TIM_SYSTEM_USERNAME}"

# verify user was added
if ! id -u "${TIM_SYSTEM_USERNAME}"; then
    die "Error creating user ${TIM_SYSTEM_USERNAME}."
fi

##
## - install git, gh, gpg
## - create GPG key and associate it with git
## - create SSH key
##

# install git
apt-get update
apt-get -y install software-properties-common
add-apt-repository -y ppa:git-core/ppa
apt-get update
if ! apt-get install -y git; then
    die "Git failed to install"
fi

# configure git for user
sudo -u "${TIM_SYSTEM_USERNAME}" git config --global user.name "${TIM_REAL_NAME}"
sudo -u "${TIM_SYSTEM_USERNAME}" git config --global user.email ${TIM_EMAIL}

# install gh (github cli tools)
# check whether `curl` is installed
if program-not-available curl; then
    printf -- "* 'curl' was not detected. Will try to install 'curl'.\n"
    apt-get update

    # verify curl installation
    if ! apt-get install -y curl; then
        die "'curl' installation failed."
    fi

    printf -- "* 'curl' was installed successfully.\n"
fi

curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
printf -- "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main\n" | tee /etc/apt/sources.list.d/github-cli.list > /dev/null
apt-get update


# verify gh installation
if ! apt-get -y install gh; then
    die "'gh' failed to install."
fi

##
## install gpg, create GPG key, associate it with git
##

# check whether gpg is installed
if program-not-available gpg; then
    printf -- "* GPG was not detected. Will try to install gpg.\n"
    apt-get update
    
    # verify gpg installation
    if ! apt-get install -y gpg; then
        die "GPG installation failed."
    fi

    printf -- "* GPG was installed successfully.\n"
fi

# set local variables
TIM_GPG_NAME_REAL=${TIM_REAL_NAME}
TIM_GPG_NAME_EMAIL=${TIM_EMAIL}

GPG_KEY_CONFIG_FILE=${HOME_DIR}gpg-key-config.txt
GPG_SSH_KEYS_SCRIPT_FILE=${HOME_DIR}create-gpg-ssh-keys.sh

# first create config file for GPG key
cat <<EOF > "${GPG_KEY_CONFIG_FILE}"
Key-Type: 1
Key-Length: 4096
Subkey-Type: 1
Subkey-Length: 4096
Name-Real: ${TIM_GPG_NAME_REAL}
Name-Email: ${TIM_GPG_NAME_EMAIL}
Expire-Date: 0

EOF

# create script that will be run under tim's account
cat <<EOF > "${GPG_SSH_KEYS_SCRIPT_FILE}"
#!/usr/bin/env bash

# create GPG key
printf -- "Creating GPG key..."

# check for error
if ! gpg --batch --quiet --pinentry-mode loopback --passphrase "" --gen-key ${GPG_KEY_CONFIG_FILE} ; then
    printf -- "Error: Failed to create GPG key.\n"
    printf -- "Aborting script.\n"
    exit 1
fi

gpg --list-secret-keys --keyid-format=long

# configure GPG key for use with git
LONG_FORM_GPG_KEY=\$(gpg --list-secret-keys --keyid-format=long | grep "sec" | sed "s|.*rsa4096/||" | sed "s|\ .*||")
git config --global user.signingkey \${LONG_FORM_GPG_KEY}

# create and update .bashrc_local
cat <<EOT > ${HOME_DIR}.bashrc_local

export GPG_TTY=\$(tty)

EOT

# display public GPG key to user
printf -- "\n*\n*\n*\n"
printf -- "* Your public GPG key follows:\n"
printf -- "* \$(whoami) on \$(hostname)\n"
printf -- "*\n*\n*\n\n"
gpg --armor --export \$LONG_FORM_GPG_KEY
printf -- "\n\n"

# create and add SSH key
printf -- "Creating SSH key...\n"
ssh-keygen -o -a 100 -t ed25519 -f ${HOME_DIR}.ssh/id_ed25519 -q -N "" -C ${TIM_EMAIL}
ssh-agent -s
eval \`ssh-agent -s\`

# check for error
if ! ssh-add ${HOME_DIR}.ssh/id_ed25519; then
    printf -- "Error: Failed to add SSH key for user ${TIM_SYSTEM_USERNAME}. (Maybe there was a problem with the ssh-agent.)\n"
    printf -- "Aborting script.\n"
    exit 1
fi

printf -- "\n*\n*\n*\n"
printf -- "* Your public SSH key follows:\n"
printf -- "* \$(whoami) on \$(hostname)\n"
printf -- "*\n*\n*\n\n"
cat ${HOME_DIR}.ssh/id_ed25519.pub
printf -- "\n\n"

EOF

# update permissions and run the GPG and SSH keys script as user
chmod +x "${GPG_SSH_KEYS_SCRIPT_FILE}"
chown "${TIM_SYSTEM_USERNAME}:${TIM_SYSTEM_USERNAME}" "${GPG_KEY_CONFIG_FILE}"
chown "${TIM_SYSTEM_USERNAME}:${TIM_SYSTEM_USERNAME}" "${GPG_SSH_KEYS_SCRIPT_FILE}"

sudo -u "${TIM_SYSTEM_USERNAME}" "${GPG_SSH_KEYS_SCRIPT_FILE}" || die "Error: Could not create or configure one or more of GPG key or SSH key. Script ${GPG_SSH_KEYS_SCRIPT_FILE} failed. See any messages above."

##
## display GPG and SSH keys for user to add to GitHub settings
##

tee <<EOF

*
* Now it's time to add the public GPG key and public SSH key
* shown above to your github.com settings.
*
* Visit: https://github.com/settings/keys
*
* After you've added those keys to github, hit 'Enter' to continue.
* Otherwise, type 'quit' to quit.
*

EOF

read -r USER_INPUT

if [[ "$USER_INPUT" == *"quit"* ]]; then
    printf -- "Quitting!\n"
    printf -- "Aborting script.\n"
    exit 1
fi

##
## clone git repo that contains the remaining scripts
##

# create script to do the cloning that we'll run as the new user
cat <<EOF > "${CLONE_SCRIPT_NAME}"
#!/usr/bin/env bash

cd ${HOME_DIR} || exit 1

# add github.com to known_hosts
ssh -o 'StrictHostKeyChecking accept-new' -T git@github.com

# clone into conv-scripts repo
git clone ${CONV_SCRIPTS_URL}

EOF

# update permissions and run
chmod +x "${CLONE_SCRIPT_NAME}"
chown "${TIM_SYSTEM_USERNAME}:${TIM_SYSTEM_USERNAME}" "${CLONE_SCRIPT_NAME}"
sudo -u "${TIM_SYSTEM_USERNAME}" "${CLONE_SCRIPT_NAME}" || die "script ${CLONE_SCRIPT_NAME} failed!"

##
## Remaining scripts will be brought down in the cloned repo
##

# set up user's dotfiles and directories
sudo -u "${TIM_SYSTEM_USERNAME}" ln -sf "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/dotfiles/.bash_profile" "${HOME_DIR}.bash_profile"
sudo -u "${TIM_SYSTEM_USERNAME}" ln -sf "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/dotfiles/.bashrc" "${HOME_DIR}.bashrc"
# set up root dotfiles
ln -sf "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/dotfiles/.bash_profile" /root/.bash_profile
ln -sf "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/dotfiles/.bashrc" /root/.bashrc

sudo -u "${TIM_SYSTEM_USERNAME}" mkdir "${HOME_DIR}bin"

# # install OpenSSH
# ${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/i-openssh.sh

# install Python 3
"${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/i-python3.sh"

# install other stuff
apt-get install -y apt-transport-https colordiff coreutils net-tools shellcheck software-properties-common

#
# additional quality of life enhancements
#
usermod -a -G www-data "${TIM_SYSTEM_USERNAME}"

# set up network drive
apt-get install -y nfs-common
if ping -c 2 192.168.1.142; then
    mkdir /mnt/synology
    mount -t nfs 192.168.1.142:/volume1/Main /mnt/synology
fi

# create secure cert for this host
printf -- "Creating SSL cert for $(hostname).home.arpa\n"
sudo -u "${TIM_SYSTEM_USERNAME}" "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/lp-ca-certs/create-cert.sh" -d "$(hostname).home.arpa" -p "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/lp-ca-certs/myCA.pem" -k "${HOME_DIR}${CONV_SCRIPTS_REPO_NAME}/lp-ca-certs/myCA.key" -o "${HOME_DIR}"

# create and customize .nanorc
cat <<EOF > "${HOME_DIR}/.nanorc"
set tabsize 4
set tabstospaces
set constantshow
set softwrap

EOF

if [[ ! -f /usr/bin/python ]]; then
    sudo ln -s /usr/bin/python3 /usr/bin/python
fi

chown "${TIM_SYSTEM_USERNAME}:${TIM_SYSTEM_USERNAME}" "${HOME_DIR}/.nanorc"

#
# `tim-fresh.sh` cleanup
#

apt-get update && apt upgrade -y && apt autoremove -y --purge && apt clean -y

#
# happy ending
#
tee <<EOF

*
* ${BASH_SOURCE##*/} completed successfully.
*
* \`hostname\`:    $(hostname)
* \`hostname -I\`: $(hostname -I)
*

*
* Possible next steps on Windows machine:
*     ssh-keygen -R $(hostname -I)
*     type C:\\Users\\tim\\.ssh\\id_ed25519.pub | ssh ${TIM_SYSTEM_USERNAME}@$(hostname -I) "cat >> .ssh/authorized_keys"
*
* More possible next steps::
*     update pihole DNS to route $(hostname -I) to $(hostname).home.arpa
*

EOF

exit 0

