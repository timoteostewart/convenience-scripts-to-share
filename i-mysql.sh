#!/usr/bin/env bash

source ./functions.sh

die-if-not-root

# TODO: provide a way to specify the MySQL root user password and the superuser credentials.

temp_dir=$(mktemp --directory)

printf "
*
* Installing MySQL...
*
"

apt-get -y update && apt-get -y upgrade

if ! apt-get -y install mysql-server mysql-client; then
    die "Error: MySQL failed to install."
fi
if ! mysql --version; then
    die "Error: MySQL seemed to install, but \`mysql --version\` failed."
fi
if ! systemctl start mysql.service; then
    die "Error: \`mysql.service\` failed to start."
fi

systemctl enable mysql.service

# non-interactively perform some database hardening, as with running `mysql_secure_installation`

cat << EOF > "${temp_dir}/mysql-hardening-measures.sql"
DELETE FROM mysql.user WHERE User='';
DROP USER IF EXISTS ''@'localhost';
DROP USER IF EXISTS ''@'$(hostname)';
DROP USER IF EXISTS ''@'$(hostname).home.arpa';
DROP DATABASE IF EXISTS test;
FLUSH PRIVILEGES;
CREATE USER 'tim'@'localhost' IDENTIFIED BY 'h4rdp455w0rd';
GRANT ALL PRIVILEGES ON *.* TO 'tim'@'localhost' WITH GRANT OPTION;
FLUSH PRIVILEGES;
ALTER USER 'root'@'localhost' IDENTIFIED WITH mysql_native_password BY 'h4rdp455w0rd';
FLUSH PRIVILEGES;
EOF

if mysql -u root -p < "${temp_dir}/mysql-hardening-measures.sql"; then
    rm "${temp_dir}/mysql-hardening-measures.sql"
else
    die "Error: ${temp_dir}/mysql-hardening-measures.sql failed"
fi

printf "
*
* Done installing MySQL
*
"

exit 0


################################################################################
################################################################################

Next steps:
