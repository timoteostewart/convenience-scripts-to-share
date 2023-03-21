#!/usr/bin/env bash

# Purpose: install PHP 8.2, latest Composer, and latest Drush, and then install a Drupal site to a directory
# Author: Tim Stewart <tim@texastim.dev>
# Last revised: 3/8/2023

# debugging switches
# set -o errexit   # abort on nonzero exit status; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

##
## helper functions
##

# usage: die "$MESSAGE"
die() {
    printf >&2 "\n*\n* Error: ${1:-Unspecified error.}\n* This error is unrecoverable. Check above for additional error messages.\n*\n\n"
    exit 1
}

# usage: am-root
# returns 0 if root, 1 if not root
am-root() {
    if ((${EUID:-$(id -u)} != 0)); then
        return 1
    else
        return 0
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

##
## global variables
##

print_usage() {
    printf "
Usage: $ ./${BASH_SOURCE##*/} -i INSTALL_DIR -s SITE_NAME -u URI -m MYSQL_HOST -n DATABASE_NAME -x DB_DRUPAL_USER -y DB_DRUPAL_PASSWORD

Example: $ ./${BASH_SOURCE##*/} -i /srv/drupal-site -s "My Cool Drupal Site" -u https://drupal-site.example.com -m localhost -n drupal_data -x drupal_user -y h4rdp455w0rd

   -i
       directory to install Drupal in. Will be the directory where 'composer.json' and './web' live, etc.
       It must be accessible and writeable by the user executing this script.
   -s
       site name for the new Drupal install.
   -u
       URI that the Drupal website will use.
   -m
       host where the MySQL server is. E.g., "localhost" or "https://mysql.example.com".
   -n
       name of the MySQL database for Drupal to use
   -x
       MySQL username for Drupal to use
   -y
       password for Drupal's MySQL username

Note: Don't run this script as root or by using ‘sudo’. Instead run this script as a non-root user who has sudo privileges. Sudo will be requested as needed during execution of the script.

"
}

if am-root; then
    die "Please don't run this script as root or by using ‘sudo’. Instead run this script as a non-root user who has sudo privileges. Sudo will be requested as needed during execution of the script."
fi

# validate command-line arguments
while getopts "i:s:u:m:n:x:y:" opt; do
    case "${opt}" in
    i) DRUPAL_INSTALL_DIR=${OPTARG} ;;
    s) DRUPAL_SITE_NAME=${OPTARG} ;;
    u) DRUPAL_URI=${OPTARG} ;;
    m) DB_MYSQL_HOST=${OPTARG} ;;
    n) DB_DRUPAL_DATABASE_NAME=${OPTARG} ;;
    x) DB_DRUPAL_USERNAME=${OPTARG} ;;
    y) DB_DRUPAL_USER_PASSWORD=${OPTARG} ;;
    *)
        printf "Unrecognized argument used.\n"
        print_usage
        exit 1
        ;;
    esac
done

# check if target dir exists
if [[ ! -d ${DRUPAL_INSTALL_DIR} ]]; then
    if ! mkdir -p ${DRUPAL_INSTALL_DIR}; then
        die "Could not create directory ‘${DRUPAL_INSTALL_DIR}’. (Does the current non-root user have permission to create this directory?)"
    else
        printf "Created directory ‘${DRUPAL_INSTALL_DIR}’.\n"
    fi
else
    if [[ ! -w ${DRUPAL_INSTALL_DIR} ]]; then
        die "Directory ‘${DRUPAL_INSTALL_DIR}’ exists but isn't writeable by the current non-root user."
    fi
fi

##
## install dependencies: PHP 8.2, latest Composer, latest Drush
##

#
# PHP 8.2
#
sudo apt-get -y update && apt-get -y upgrade
sudo apt-get -y install \
    apt-transport-https \
    ca-certificates \
    lsb-release \
    software-properties-common \
    unzip
sudo add-apt-repository -y ppa:ondrej/php
sudo apt-get -y update && apt-get -y upgrade
sudo apt-get -y install \
    libapache2-mod-php \
    php8.2 \
    php8.2-cli \
    php8.2-common \
    php8.2-curl \
    php8.2-fpm \
    php8.2-gd \
    php8.2-imap \
    php8.2-mbstring \
    php8.2-mysql \
    php8.2-pgsql \
    php8.2-redis \
    php8.2-snmp \
    php8.2-sqlite3 \
    php8.2-xml \
    php8.2-zip
die-if-program-not-available php "For some reason, PHP didn't install."
php --version

#
# Composer
#
DRUPAL_INSTALLER_DIR=$(mktemp -d)
curl --fail --location --silent --show-error https://getcomposer.org/installer | dd of="${DRUPAL_INSTALLER_DIR}/composer-setup.php"
curl --fail --location --silent --show-error https://composer.github.io/installer.sig | dd of="${DRUPAL_INSTALLER_DIR}/composer-installer-hash.txt"
CORRECT_HASH=$(cat "${DRUPAL_INSTALLER_DIR}/composer-installer-hash.txt")
ACTUAL_HASH=$(php -r "print(hash_file('SHA384', \"${DRUPAL_INSTALLER_DIR}/composer-setup.php\"));")
if [[ ${CORRECT_HASH} != ${ACTUAL_HASH} ]]; then
    die "SHA384 hash of \"${DRUPAL_INSTALLER_DIR}/composer-setup.php\" doesn't match https://composer.github.io/installer.sig"
else
    printf "SHA384 hash of \"${DRUPAL_INSTALLER_DIR}/composer-setup.php\" matches https://composer.github.io/installer.sig"
fi
export COMPOSER_ALLOW_SUPERUSER=1
sudo php "${DRUPAL_INSTALLER_DIR}/composer-setup.php" --install-dir=/usr/local/bin --filename=composer
die-if-program-not-available composer "For some reason, Composer didn't install."
composer --version

#
# Drush
#
curl --fail --location --silent --show-error https://github.com/drush-ops/drush-launcher/releases/latest/download/drush.phar | dd of="${DRUPAL_INSTALLER_DIR}/drush.phar"
chmod +x "${DRUPAL_INSTALLER_DIR}/drush.phar"
sudo mv "${DRUPAL_INSTALLER_DIR}/drush.phar" /usr/local/bin/drush
sudo export COMPOSER_ALLOW_SUPERUSER=1
# composer global require drush/drush  # maybe not do
drush --version

##
## install latest Drupal
##
cd ${DRUPAL_INSTALL_DIR}

composer require drush/drush
composer create-project drupal/recommended-project ${DRUPAL_INSTALL_DIR}

drush -y site:install standard --db-url="mysql://${DB_DRUPAL_USERNAME}:${DB_DRUPAL_USER_PASSWORD}@${DB_MYSQL_HOST}/${DB_DRUPAL_DATABASE_NAME}" --site-name="${DRUPAL_SITE_NAME}" --uri "${DRUPAL_URI}"

drush -y config-set system.performance css.preprocess 0
drush -y config-set system.performance js.preprocess 0

printf "

Drupal seems to have installed correctly. Files were extracted to: ${DRUPAL_INSTALL_DIR}

Possible next steps:

    - create MySQL database
    CREATE DATABASE drupal_db /*!40100 DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_0900_ai_ci */ /*!80016 DEFAULT ENCRYPTION='N' */;
    CREATE USER 'drupal_user'@'%' IDENTIFIED WITH mysql_native_password BY 'h4rdp455w0rd';
    GRANT ALL PRIVILEGES ON drupal_db.* TO 'drupal_user'@'%';
    FLUSH PRIVILEGES;


"

exit 0

################################################################################
################################################################################
