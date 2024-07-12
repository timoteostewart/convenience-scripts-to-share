#!/bin/bash

# debugging switches
# set -o errexit   # abort on nonzero exit status; same as set -e
# set -o nounset   # abort on unbound variable; same as set -u
# set -o pipefail  # don't hide errors within pipes
# set -o xtrace    # show commands being executed; same as set -x
# set -o verbose   # verbose mode; same as set -v

# purpose: sets up sendmail as MTA on a Debian-based system using Fastmail's SMTP server

# typical invocation:
# FASTMAIL_EMAIL_ADDRESS="xxx@fastmail.com" FASTMAIL_APP_SPECIFIC_PASSWORD="a1b2c3d4e5f6a7b8" ./setup-mta-sendmail.sh

# check for root/sudo
EUID_copy="${EUID:-$(id -u)}"
if [[ -z "${EUID_copy}" ]]; then
    printf "This script must be run as root, and the current user's EUID could not be determined.\n" >&2 && exit 1
elif ((EUID_copy != 0)); then
    printf "This script must be run as root.\n" >&2 && exit 1
fi

# check for active postfix service
if systemctl is-active --quiet postfix; then
    printf "This script requires postfix to already be uninstalled, e.g., via \`apt remove postfix\`.\n" >&2 && exit 1
fi

# check for required arguments
[[ -z "${FASTMAIL_EMAIL_ADDRESS}" && -z "${FASTMAIL_APP_SPECIFIC_PASSWORD}" ]] && printf "env vars FASTMAIL_EMAIL_ADDRESS and FASTMAIL_APP_SPECIFIC_PASSWORD must be set.\n" >&2 && exit 1
[[ -z "${FASTMAIL_EMAIL_ADDRESS}" ]] && printf "env var FASTMAIL_EMAIL_ADDRESS must be set.\n" >&2 && exit 1
[[ -z "${FASTMAIL_APP_SPECIFIC_PASSWORD}" ]] && printf "env var FASTMAIL_APP_SPECIFIC_PASSWORD must be set.\n" >&2 && exit 1

# set defaults
[[ -z "${SMTP_SERVER}" ]] && SMTP_SERVER="smtp.fastmail.com"
[[ -z "${SMTP_PORT}" ]] && SMTP_PORT="587"
SENDMAIL_CONFIG_FILE_MC="/etc/mail/sendmail.mc"
SENDMAIL_CONFIG_FILE_CF="/etc/mail/sendmail.cf"
SENDMAIL_KEY_FILE="/etc/ssl/private/sendmail-key.pem"
SENDMAIL_CERT_FILE="/etc/ssl/certs/sendmail-cert.pem"
SMTP_AUTH_FILE="/etc/mail/authinfo"

# set up SSL/TLS
apt-get -y install libsasl2-modules openssl sasl2-bin
mkdir -p /etc/ssl/certs /etc/ssl/private
# backup existing SSL/TLS files, if present
if [[ -f "${SENDMAIL_KEY_FILE}" ]]; then
    cp "${SENDMAIL_KEY_FILE}" "${SENDMAIL_KEY_FILE}".bak
fi
if [[ -f "${SENDMAIL_CERT_FILE}" ]]; then
    cp "${SENDMAIL_CERT_FILE}" "${SENDMAIL_CERT_FILE}".bak
fi
openssl req -x509 -newkey rsa:4096 -keyout "${SENDMAIL_KEY_FILE}" -out "${SENDMAIL_CERT_FILE}" -days 365 -nodes
chmod 600 "${SENDMAIL_KEY_FILE}"

apt-get -y install mailutils sendmail sendmail-cf

printf "AuthInfo:${SMTP_SERVER} \"U:${FASTMAIL_EMAIL_ADDRESS}\" \"I:${FASTMAIL_EMAIL_ADDRESS}\" \"P:${FASTMAIL_APP_SPECIFIC_PASSWORD}\"\n" >"${SMTP_AUTH_FILE}"
makemap hash "${SMTP_AUTH_FILE}" <"${SMTP_AUTH_FILE}"

cp "${SENDMAIL_CONFIG_FILE_MC}" "${SENDMAIL_CONFIG_FILE_MC}.bak"

sendmail_mc_lines_to_delete=(
    "MAILER_DEFINITIONS"
    "MAILER(\`local')dnl"
    "MAILER(\`smtp')dnl"
)

for pattern in "${sendmail_mc_lines_to_delete[@]}"; do
    sed -i "/${pattern}/d" "${SENDMAIL_CONFIG_FILE_MC}"
done

printf "

FEATURE(\`authinfo', \`hash -o ${SMTP_AUTH_FILE}.db')dnl
TRUST_AUTH_MECH(\`EXTERNAL DIGEST-MD5 CRAM-MD5 LOGIN PLAIN')dnl
define(\`ESMTP_MAILER_ARGS', \`TCP \$h ${SMTP_PORT}')dnl
define(\`RELAY_MAILER_ARGS', \`TCP \$h ${SMTP_PORT}')dnl
define(\`SMART_HOST', \`[smtp.fastmail.com]')dnl
define(\`confAUTH_MECHANISMS', \`EXTERNAL GSSAPI DIGEST-MD5 CRAM-MD5 LOGIN PLAIN')dnl
define(\`confAUTH_OPTIONS', \`A p')dnl
define(\`confCACERT', \`/etc/ssl/certs/ca-certificates.crt')dnl
define(\`confCACERT_PATH', \`/etc/ssl/certs')dnl
define(\`confSERVER_CERT', \`/etc/ssl/certs/sendmail-cert.pem')dnl
define(\`confSERVER_KEY', \`/etc/ssl/private/sendmail-key.pem')dnl

MAILER_DEFINITIONS
MAILER(\`local')dnl
MAILER(\`smtp')dnl" >>"${SENDMAIL_CONFIG_FILE_MC}"

m4 "${SENDMAIL_CONFIG_FILE_MC}" >"${SENDMAIL_CONFIG_FILE_CF}"

systemctl restart sendmail

if systemctl is-active --quiet ufw; then
    ufw allow "${SMTP_PORT}"
fi

printf "This is a test email from $(hostname --fqdn) running on:\n$(lsb_release -a).\n" | sendmail "${FASTMAIL_EMAIL_ADDRESS}"

exit

# troubleshooting
tail -f /var/log/mail.log
