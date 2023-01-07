#!/usr/bin/env bash

#
# install Django with venv on Ubuntu
#

#
# settings and parameters
#
# note: in this script, variables for directories have NO trailing slash
APACHE_LOG_DIR=/var/log/apache2


# check for root
if [[ "$(id -u)" == "0" ]]; then
    echo -e "\n* Error: Please run this script as a non-root user. As needed, you will"
    echo -e "* be prompted to enter your root password to become a superuser.\n*\n"
    exit 1
fi

print_usage () {
cat << EOF
Name
    i-django.sh
Synopsis
    i-django.sh -r ROOT_DIRECTORY -p DJANGO_PROJECT_NAME [-v VENV_NAME] [-d] [-t PORT]
    i-django.sh -h

Example 1: $ ./${BASH_SOURCE##*/} -r /srv/mycoolproject -p mysite -v mysite_env -t 8080
Example 2: $ ./${BASH_SOURCE##*/} -r /srv/mycoolproject -p mysite -v mysite_env -d
Example 3: $ ./${BASH_SOURCE##*/} -h

Options
   -r
       the parent directory in which your new Django project will go. So for example,
       the options '-r /srv/mycoolproject -p mysite' would create '/srv/mycoolproject'
       if it doesn't exist (and give ownership to user running i-django.sh)
       and create the Django project from that directory.
       The equivalent shell commands would be something like:
           ~$ mkdir -p /srv/mycoolproject  # if it doesn't exist
           ~$ cd /srv/mycoolproject
           /srv/mycoolproject$ django-admin startproject mysite
       Continuing the example, Django would then create directories and files like:
           /srv/mycoolproject/mysite/
           /srv/mycoolproject/mysite/manage.py
           /srv/mycoolproject/mysite/mysite/
           /srv/mycoolproject/mysite/mysite/settings.py
           /srv/mycoolproject/mysite/mysite/urls.py
           ... etc.
       And 'create-django-project.sh' would create directories and files like:
           /srv/mycoolproject/.venv (for 'venv')
           /srv/mycoolproject/mysite.conf (for Apache)
           /srv/mycoolproject/pyproject.toml (for 'black' and other tools)
           /srv/mycoolproject/.gitignore (for git)
           
   -p
       name for your Django project. See '-r' switch above for more information.
   -v
       folder name to use instead of '.venv' for the virtual environment
   -d
       also dissite Apache's 000-default.conf (requires sudo)
   -t
       port for Apache to use for Django instead of 80
   -h
       show this help page

EOF
}

die () {
    if [[ -n "$1" ]]; then
        mesg=$1
    else
        mesg=""
    fi
    echo -e "\n*\n* ${mesg}"
    echo -e "* Error: An unrecoverable error has occurred. Look above for any error messages."
    echo -e "* The script \`${BASH_SOURCE##*/}\` will exit now.\n*\n"
    exit 1
}

# check for command-line arguments
while getopts ":r:p:v:t:hd" flag
do
    case "${flag}" in
        r) RR=${OPTARG} ;;
        p) PP=${OPTARG} ;;
        v) VV=${OPTARG}
            VFLAG=true ;;
        d) DFLAG=true ;;
        t) TT=${OPTARG}
            TFLAG=true ;;
        h) print_usage ; exit 0 ;;
        *) echo -e "Error: Unrecognized option '${OPTARG}'." ; print_usage ; exit 1 ;;
    esac
done

CMD_LINE_ARGS_AS_STRING="$*"

# `-r` switch validation: check for missing switch, or `-r` param starts with dash, or no parameter was given
if [[ -z "${RR}" ]] || [[ "${RR:0:1}" == "-" ]] || [[ "${CMD_LINE_ARGS_AS_STRING: -2}" == "-r" ]]; then
    echo -e "Error: '-r' parameter is missing or incorrect."
    echo -e "Please supply a directory in which to create your Django project (e.g., '/srv/mycoolproject')."
    print_usage
    exit 1
fi

# `-p` switch validation: check for missing switch, or `-p` param starts with dash, or no parameter was given
if [[ -z "${PP}" ]] || [[ "${PP:0:1}" == "-" ]] || [[ "${CMD_LINE_ARGS_AS_STRING: -2}" == "-p" ]]; then
    echo -e "Error: '-p' parameter is missing or incorrect."
    echo -e "Please supply a name for your Django project (e.g., 'mysite')."
    print_usage
    exit 1
fi

# `-v` switch validation begins here...
# case: arg after `-v` started with dash, suggesting that the arg for `-v` was omitted
if [ "${VV:0:1}" == "-" ]; then
    echo "Error: '-v' parameter is missing or incorrect."
    echo -e "The optional '-v' switch requires a name for the virtual environment's directory."
    print_usage
    exit 1
fi

# case: `-v` switch appeared in the command line arguments but no parameter was supplied
if [[ -z "${VV}" && "${CMD_LINE_ARGS_AS_STRING: -2}" == "-v" ]]; then
    echo "Error: '-v' switch requires a parameter."
    echo -e "The optional '-v' switch requires a name for the virtual environment's directory."
    print_usage
    exit 1
fi

# `-t` switch validation begins here...
# case: arg after `-t` started with dash, suggesting that the arg for `-t` was omitted
if [ "${TT:0:1}" == "-" ]; then
    echo "Error: '-t' parameter is missing or incorrect."
    echo -e "The optional '-t' switch requires the port number Django and Apache will use."
    print_usage
    exit 1
fi

# case: `-t` switch appeared in the command line arguments but no parameter was supplied
if [[ -z "${TT}" && "${CMD_LINE_ARGS_AS_STRING: -2}" == "-t" ]]; then
    echo "Error: '-t' switch requires a parameter."
    echo -e "The optional '-t' switch requires the port number Django and Apache will use."
    print_usage
    exit 1
fi

if [ "${DFLAG}" != "true" ]; then
    DFLAG=false
fi

# echo -e "Summary of options:"
# echo -e "-r ${RR}"
# echo -e "-p ${PP}"
# echo -e "-v ${VV}"
# echo -e "VFLAG=${VFLAG}"
# echo -e "VENV_NAME=${VENV_NAME}"
# echo -e "DFLAG=${DFLAG}"

# translate command line parameters to script variables
ROOT_DIR=${RR}
DJANGO_PROJECT_NAME=${PP}
DISSITE_DEFAULT=${DFLAG}

if [ "${VFLAG}" == "true" ]; then
    VENV_NAME=${VV}
else
    VENV_NAME=".venv"
fi

if [ "${TFLAG}" == "true" ]; then
    WEB_PORT=${TT}
else
    WEB_PORT=80
fi


#
# Check whether Apache is installed
#

if ! sudo dpkg -s apache2 1> /dev/null 2> /dev/null; then
    echo -e "Apache not yet installed. Installing now..."
    if ! sudo ./i-apache2.sh; then
        die "Error: Apache2 failed to install."
    fi
fi


#
# Proceed to installation
#

sudo apt update

# libapache2-mod-wsgi-py3 below is just for apache web server setups
# uwsgi would be used for nginx and gunicorn setups
sudo apt install -y python3-pip python3-venv libapache2-mod-wsgi-py3 sqlite3

# attempt to create directory to hold the new Django project
if ! [[ -d "${ROOT_DIR}" ]]; then
    if ! mkdir -p "${ROOT_DIR}"; then
        echo -e "*\n* Could not 'mkdir' ${ROOT_DIR}, so will try again using 'sudo'..."
        sudo mkdir -p "${ROOT_DIR}"
        CUR_USER=$(whoami)
        sudo chown "${CUR_USER}:${CUR_USER}" "${ROOT_DIR}"
        if ! [[ -d "${ROOT_DIR}" ]]; then
            die "* Could not create ${ROOT_DIR}, even with sudo"
        else
            echo -e "* ...and 'sudo' worked! \n*"
        fi
    fi
fi


# verify whether user has write permissions to this directory
RANDOM_FILENAME="${RANDOM}${RANDOM}${RANDOM}.txt"
touch "${ROOT_DIR}/${RANDOM_FILENAME}" || die "don't have write permissions to ${ROOT_DIR}"
rm "${ROOT_DIR}/${RANDOM_FILENAME}"

# start creating the Django project
cd "${ROOT_DIR}" || die "could not 'cd' to ${ROOT_DIR}"
python3 -m venv "${VENV_NAME}"

source "${ROOT_DIR}/${VENV_NAME}/bin/activate"
python -m pip install --upgrade pip
pip install django black isort djlint

django-admin --version
django-admin startproject "${DJANGO_PROJECT_NAME}"
cd "${ROOT_DIR}/${DJANGO_PROJECT_NAME}" || die "could not cd to ${ROOT_DIR}/${DJANGO_PROJECT_NAME}"

python manage.py migrate

# modify settings.py
SETTINGS_PY_FILE="${ROOT_DIR}/${DJANGO_PROJECT_NAME}/${DJANGO_PROJECT_NAME}/settings.py"
sed -i "s/^from pathlib import Path/from pathlib import Path\nimport os\n\nimport secret_key\n\n\nos.environ['DJANGO_SETTINGS_MODULE'] = '${DJANGO_PROJECT_NAME}.settings'/g" "${SETTINGS_PY_FILE}"
grep "^SECRET_KEY" "${SETTINGS_PY_FILE}" > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/secret_key.py"
sed -i "s/^SECRET_KEY.*/SECRET_KEY = secret_key.SECRET_KEY/g" "${SETTINGS_PY_FILE}"
sed -i "s/^ALLOWED_HOSTS = \[\]/ALLOWED_HOSTS = ['*']/g" "${SETTINGS_PY_FILE}"
sed -i "s/\"DIRS\".*/'DIRS': [os.path.join(BASE_DIR, 'templates'),],/g" "${SETTINGS_PY_FILE}"
sed -i "s/^STATIC_URL.*/STATIC_URL = 'static\/'\nSTATIC_ROOT = os.path.join(BASE_DIR, 'staticfiles')/g" "${SETTINGS_PY_FILE}"
# to enable use of MEDIA_ROOT and MEDIA_URL
sed -i "s/\"django.contrib.messages.context_processors.messages\",/\"django.contrib.messages.context_processors.messages\",\n                \"django.template.context_processors.media\",/g" "${SETTINGS_PY_FILE}"
# new settings to add to settings.py
cat <<EOF >> "${SETTINGS_PY_FILE}"

# next line will break Django if you're using a direct IP address (e.g., http://192.168.1.230)
#PREPEND_WWW = True

APPEND_SLASH = True

MEDIA_URL = "media/"
MEDIA_ROOT = os.path.join(BASE_DIR, "mediafiles")

STATICFILES_DIRS = ['${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static']

# new in Django 4.1
SECRET_KEY_FALLBACKS = []

EOF

sed -i "s/import os/import os\nimport sys\nsys.path.append('\/var\/www\/${DJANGO_PROJECT_FOLDER_NAME}\/${DJANGO_PROJECT_NAME}\/${DJANGO_PROJECT_NAME}')/g" "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/${DJANGO_PROJECT_NAME}/wsgi.py"

# additional config needed to ensure Apache2's WSGI can access Django's database
sudo chown www-data:www-data "${ROOT_DIR}/${DJANGO_PROJECT_NAME}"
sudo chown www-data:www-data "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/db.sqlite3"
sudo chmod 664 "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/db.sqlite3"
echo -e "\n# Needed by the Django site in ${ROOT_DIR}/${DJANGO_PROJECT_NAME}\nWSGIApplicationGroup %{GLOBAL}\n" | sudo tee -a /etc/apache2/apache2.conf > /dev/null

# create `pyproject.toml`
cat <<EOF > "${ROOT_DIR}/pyproject.toml"

[tool.black]
extend-exclude = '''
'''

[tool.djlint]
ignore="H031"


EOF

# create or append to `.gitignore`
if [[ -f "${ROOT_DIR}/.gitignore" ]]; then
cat <<EOF >> "${ROOT_DIR}/.gitignore"

${VENV_NAME}/
__pycache__/
secrets.txt
secret_key.py

EOF
else
cat <<EOF > "${ROOT_DIR}/.gitignore"

${VENV_NAME}/
__pycache__/
secrets.txt
secret_key.py

EOF
fi

if ! [[ -d "${ROOT_DIR}/apache2_files" ]]; then
    if ! mkdir -p "${ROOT_DIR}/apache2_files"; then
        echo -e "*\n* Could not 'mkdir' ${ROOT_DIR}/apache2_files, so will try again using 'sudo'..."
        sudo mkdir -p "${ROOT_DIR}/apache2_files"
        CUR_USER=$(whoami)
        sudo chown "${CUR_USER}:${CUR_USER}" "${ROOT_DIR}"
        if ! [[ -d "${ROOT_DIR}/apache2_files" ]]; then
            die "* Could not create ${ROOT_DIR}/apache2_files, even with sudo"
        else
            echo -e "* ...and 'sudo' worked! \n*"
        fi
    fi
fi

# create additional commonly used directories
mkdir "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/doc"
mkdir "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/media"
mkdir "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static"
mkdir "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/templates"
mkdir "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/tests"

touch "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static/styles.css"

# a minimal favicon.ico (a placeholder to avoid web server complaints)
favicon_ico="AAABAAEAEBAQAAAAAAAoAQAAFgAAACgAAAAQAAAAIAAAAAEABAAAAAAAgAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAEhEQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAD//wAA//8AAP//AAD//wAA//8AAP//AAD//wAA//8AAP7/AAD//wAA//8AAP//AAD//wAA//8AAP//AAD//wAA"
echo ${favicon_ico} | base64 -d > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static/favicon.ico"

# a minimal apple-touch-icon.png (a placeholder to avoid web server complaints)
apple_touch_icon_png="iVBORw0KGgoAAAANSUhEUgAAABAAAAAQCAYAAAAf8/9hAAAAAXNSR0IArs4c6QAAAARnQU1BAACxjwv8YQUAAAAJcEhZcwAADsIAAA7CARUoSoAAAAAgSURBVDhPY/wPBAwUACYoTTYYNWDUABAYNWDgDWBgAABrygQclUTopgAAAABJRU5ErkJggg=="
echo ${apple_touch_icon_png} | base64 -d > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static/apple-touch-icon.png"

# a minimal favicon.svg (a placeholder to avoid web server complaints)
favicon_svg="PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0iVVRGLTgiIHN0YW5kYWxvbmU9Im5vIj8+CjxzdmcKICAgd2lkdGg9IjE2bW0iCiAgIGhlaWdodD0iMTZtbSIKICAgdmlld0JveD0iMCAwIDE2IDE2IgogICB2ZXJzaW9uPSIxLjEiCiAgIGlkPSJzdmc1IgogICB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciCiAgIHhtbG5zOnN2Zz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciPgogIDxkZWZzIGlkPSJkZWZzMiIgLz4KICA8ZyBpZD0ibGF5ZXIxIiAvPgo8L3N2Zz4K"
echo ${favicon_svg} | base64 -d > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static/favicon.svg"

# normalize.css v8.0.1 | MIT License | github.com/necolas/normalize.css
normalize_css="LyohIG5vcm1hbGl6ZS5jc3MgdjguMC4xIHwgTUlUIExpY2Vuc2UgfCBnaXRodWIuY29tL25lY29sYXMvbm9ybWFsaXplLmNzcyAqLw0KDQovKiBEb2N1bWVudA0KICAgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0gKi8NCg0KLyoqDQogKiAxLiBDb3JyZWN0IHRoZSBsaW5lIGhlaWdodCBpbiBhbGwgYnJvd3NlcnMuDQogKiAyLiBQcmV2ZW50IGFkanVzdG1lbnRzIG9mIGZvbnQgc2l6ZSBhZnRlciBvcmllbnRhdGlvbiBjaGFuZ2VzIGluIGlPUy4NCiAqLw0KDQpodG1sIHsNCiAgbGluZS1oZWlnaHQ6IDEuMTU7IC8qIDEgKi8NCiAgLXdlYmtpdC10ZXh0LXNpemUtYWRqdXN0OiAxMDAlOyAvKiAyICovDQp9DQoNCi8qIFNlY3Rpb25zDQogICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSAqLw0KDQovKioNCiAqIFJlbW92ZSB0aGUgbWFyZ2luIGluIGFsbCBicm93c2Vycy4NCiAqLw0KDQpib2R5IHsNCiAgbWFyZ2luOiAwOw0KfQ0KDQovKioNCiAqIFJlbmRlciB0aGUgYG1haW5gIGVsZW1lbnQgY29uc2lzdGVudGx5IGluIElFLg0KICovDQoNCm1haW4gew0KICBkaXNwbGF5OiBibG9jazsNCn0NCg0KLyoqDQogKiBDb3JyZWN0IHRoZSBmb250IHNpemUgYW5kIG1hcmdpbiBvbiBgaDFgIGVsZW1lbnRzIHdpdGhpbiBgc2VjdGlvbmAgYW5kDQogKiBgYXJ0aWNsZWAgY29udGV4dHMgaW4gQ2hyb21lLCBGaXJlZm94LCBhbmQgU2FmYXJpLg0KICovDQoNCmgxIHsNCiAgZm9udC1zaXplOiAyZW07DQogIG1hcmdpbjogMC42N2VtIDA7DQp9DQoNCi8qIEdyb3VwaW5nIGNvbnRlbnQNCiAgID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09ICovDQoNCi8qKg0KICogMS4gQWRkIHRoZSBjb3JyZWN0IGJveCBzaXppbmcgaW4gRmlyZWZveC4NCiAqIDIuIFNob3cgdGhlIG92ZXJmbG93IGluIEVkZ2UgYW5kIElFLg0KICovDQoNCmhyIHsNCiAgYm94LXNpemluZzogY29udGVudC1ib3g7IC8qIDEgKi8NCiAgaGVpZ2h0OiAwOyAvKiAxICovDQogIG92ZXJmbG93OiB2aXNpYmxlOyAvKiAyICovDQp9DQoNCi8qKg0KICogMS4gQ29ycmVjdCB0aGUgaW5oZXJpdGFuY2UgYW5kIHNjYWxpbmcgb2YgZm9udCBzaXplIGluIGFsbCBicm93c2Vycy4NCiAqIDIuIENvcnJlY3QgdGhlIG9kZCBgZW1gIGZvbnQgc2l6aW5nIGluIGFsbCBicm93c2Vycy4NCiAqLw0KDQpwcmUgew0KICBmb250LWZhbWlseTogbW9ub3NwYWNlLCBtb25vc3BhY2U7IC8qIDEgKi8NCiAgZm9udC1zaXplOiAxZW07IC8qIDIgKi8NCn0NCg0KLyogVGV4dC1sZXZlbCBzZW1hbnRpY3MNCiAgID09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09ICovDQoNCi8qKg0KICogUmVtb3ZlIHRoZSBncmF5IGJhY2tncm91bmQgb24gYWN0aXZlIGxpbmtzIGluIElFIDEwLg0KICovDQoNCmEgew0KICBiYWNrZ3JvdW5kLWNvbG9yOiB0cmFuc3BhcmVudDsNCn0NCg0KLyoqDQogKiAxLiBSZW1vdmUgdGhlIGJvdHRvbSBib3JkZXIgaW4gQ2hyb21lIDU3LQ0KICogMi4gQWRkIHRoZSBjb3JyZWN0IHRleHQgZGVjb3JhdGlvbiBpbiBDaHJvbWUsIEVkZ2UsIElFLCBPcGVyYSwgYW5kIFNhZmFyaS4NCiAqLw0KDQphYmJyW3RpdGxlXSB7DQogIGJvcmRlci1ib3R0b206IG5vbmU7IC8qIDEgKi8NCiAgdGV4dC1kZWNvcmF0aW9uOiB1bmRlcmxpbmU7IC8qIDIgKi8NCiAgdGV4dC1kZWNvcmF0aW9uOiB1bmRlcmxpbmUgZG90dGVkOyAvKiAyICovDQp9DQoNCi8qKg0KICogQWRkIHRoZSBjb3JyZWN0IGZvbnQgd2VpZ2h0IGluIENocm9tZSwgRWRnZSwgYW5kIFNhZmFyaS4NCiAqLw0KDQpiLA0Kc3Ryb25nIHsNCiAgZm9udC13ZWlnaHQ6IGJvbGRlcjsNCn0NCg0KLyoqDQogKiAxLiBDb3JyZWN0IHRoZSBpbmhlcml0YW5jZSBhbmQgc2NhbGluZyBvZiBmb250IHNpemUgaW4gYWxsIGJyb3dzZXJzLg0KICogMi4gQ29ycmVjdCB0aGUgb2RkIGBlbWAgZm9udCBzaXppbmcgaW4gYWxsIGJyb3dzZXJzLg0KICovDQoNCmNvZGUsDQprYmQsDQpzYW1wIHsNCiAgZm9udC1mYW1pbHk6IG1vbm9zcGFjZSwgbW9ub3NwYWNlOyAvKiAxICovDQogIGZvbnQtc2l6ZTogMWVtOyAvKiAyICovDQp9DQoNCi8qKg0KICogQWRkIHRoZSBjb3JyZWN0IGZvbnQgc2l6ZSBpbiBhbGwgYnJvd3NlcnMuDQogKi8NCg0Kc21hbGwgew0KICBmb250LXNpemU6IDgwJTsNCn0NCg0KLyoqDQogKiBQcmV2ZW50IGBzdWJgIGFuZCBgc3VwYCBlbGVtZW50cyBmcm9tIGFmZmVjdGluZyB0aGUgbGluZSBoZWlnaHQgaW4NCiAqIGFsbCBicm93c2Vycy4NCiAqLw0KDQpzdWIsDQpzdXAgew0KICBmb250LXNpemU6IDc1JTsNCiAgbGluZS1oZWlnaHQ6IDA7DQogIHBvc2l0aW9uOiByZWxhdGl2ZTsNCiAgdmVydGljYWwtYWxpZ246IGJhc2VsaW5lOw0KfQ0KDQpzdWIgew0KICBib3R0b206IC0wLjI1ZW07DQp9DQoNCnN1cCB7DQogIHRvcDogLTAuNWVtOw0KfQ0KDQovKiBFbWJlZGRlZCBjb250ZW50DQogICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSAqLw0KDQovKioNCiAqIFJlbW92ZSB0aGUgYm9yZGVyIG9uIGltYWdlcyBpbnNpZGUgbGlua3MgaW4gSUUgMTAuDQogKi8NCg0KaW1nIHsNCiAgYm9yZGVyLXN0eWxlOiBub25lOw0KfQ0KDQovKiBGb3Jtcw0KICAgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0gKi8NCg0KLyoqDQogKiAxLiBDaGFuZ2UgdGhlIGZvbnQgc3R5bGVzIGluIGFsbCBicm93c2Vycy4NCiAqIDIuIFJlbW92ZSB0aGUgbWFyZ2luIGluIEZpcmVmb3ggYW5kIFNhZmFyaS4NCiAqLw0KDQpidXR0b24sDQppbnB1dCwNCm9wdGdyb3VwLA0Kc2VsZWN0LA0KdGV4dGFyZWEgew0KICBmb250LWZhbWlseTogaW5oZXJpdDsgLyogMSAqLw0KICBmb250LXNpemU6IDEwMCU7IC8qIDEgKi8NCiAgbGluZS1oZWlnaHQ6IDEuMTU7IC8qIDEgKi8NCiAgbWFyZ2luOiAwOyAvKiAyICovDQp9DQoNCi8qKg0KICogU2hvdyB0aGUgb3ZlcmZsb3cgaW4gSUUuDQogKiAxLiBTaG93IHRoZSBvdmVyZmxvdyBpbiBFZGdlLg0KICovDQoNCmJ1dHRvbiwNCmlucHV0IHsgLyogMSAqLw0KICBvdmVyZmxvdzogdmlzaWJsZTsNCn0NCg0KLyoqDQogKiBSZW1vdmUgdGhlIGluaGVyaXRhbmNlIG9mIHRleHQgdHJhbnNmb3JtIGluIEVkZ2UsIEZpcmVmb3gsIGFuZCBJRS4NCiAqIDEuIFJlbW92ZSB0aGUgaW5oZXJpdGFuY2Ugb2YgdGV4dCB0cmFuc2Zvcm0gaW4gRmlyZWZveC4NCiAqLw0KDQpidXR0b24sDQpzZWxlY3QgeyAvKiAxICovDQogIHRleHQtdHJhbnNmb3JtOiBub25lOw0KfQ0KDQovKioNCiAqIENvcnJlY3QgdGhlIGluYWJpbGl0eSB0byBzdHlsZSBjbGlja2FibGUgdHlwZXMgaW4gaU9TIGFuZCBTYWZhcmkuDQogKi8NCg0KYnV0dG9uLA0KW3R5cGU9ImJ1dHRvbiJdLA0KW3R5cGU9InJlc2V0Il0sDQpbdHlwZT0ic3VibWl0Il0gew0KICAtd2Via2l0LWFwcGVhcmFuY2U6IGJ1dHRvbjsNCn0NCg0KLyoqDQogKiBSZW1vdmUgdGhlIGlubmVyIGJvcmRlciBhbmQgcGFkZGluZyBpbiBGaXJlZm94Lg0KICovDQoNCmJ1dHRvbjo6LW1vei1mb2N1cy1pbm5lciwNClt0eXBlPSJidXR0b24iXTo6LW1vei1mb2N1cy1pbm5lciwNClt0eXBlPSJyZXNldCJdOjotbW96LWZvY3VzLWlubmVyLA0KW3R5cGU9InN1Ym1pdCJdOjotbW96LWZvY3VzLWlubmVyIHsNCiAgYm9yZGVyLXN0eWxlOiBub25lOw0KICBwYWRkaW5nOiAwOw0KfQ0KDQovKioNCiAqIFJlc3RvcmUgdGhlIGZvY3VzIHN0eWxlcyB1bnNldCBieSB0aGUgcHJldmlvdXMgcnVsZS4NCiAqLw0KDQpidXR0b246LW1vei1mb2N1c3JpbmcsDQpbdHlwZT0iYnV0dG9uIl06LW1vei1mb2N1c3JpbmcsDQpbdHlwZT0icmVzZXQiXTotbW96LWZvY3VzcmluZywNClt0eXBlPSJzdWJtaXQiXTotbW96LWZvY3VzcmluZyB7DQogIG91dGxpbmU6IDFweCBkb3R0ZWQgQnV0dG9uVGV4dDsNCn0NCg0KLyoqDQogKiBDb3JyZWN0IHRoZSBwYWRkaW5nIGluIEZpcmVmb3guDQogKi8NCg0KZmllbGRzZXQgew0KICBwYWRkaW5nOiAwLjM1ZW0gMC43NWVtIDAuNjI1ZW07DQp9DQoNCi8qKg0KICogMS4gQ29ycmVjdCB0aGUgdGV4dCB3cmFwcGluZyBpbiBFZGdlIGFuZCBJRS4NCiAqIDIuIENvcnJlY3QgdGhlIGNvbG9yIGluaGVyaXRhbmNlIGZyb20gYGZpZWxkc2V0YCBlbGVtZW50cyBpbiBJRS4NCiAqIDMuIFJlbW92ZSB0aGUgcGFkZGluZyBzbyBkZXZlbG9wZXJzIGFyZSBub3QgY2F1Z2h0IG91dCB3aGVuIHRoZXkgemVybyBvdXQNCiAqICAgIGBmaWVsZHNldGAgZWxlbWVudHMgaW4gYWxsIGJyb3dzZXJzLg0KICovDQoNCmxlZ2VuZCB7DQogIGJveC1zaXppbmc6IGJvcmRlci1ib3g7IC8qIDEgKi8NCiAgY29sb3I6IGluaGVyaXQ7IC8qIDIgKi8NCiAgZGlzcGxheTogdGFibGU7IC8qIDEgKi8NCiAgbWF4LXdpZHRoOiAxMDAlOyAvKiAxICovDQogIHBhZGRpbmc6IDA7IC8qIDMgKi8NCiAgd2hpdGUtc3BhY2U6IG5vcm1hbDsgLyogMSAqLw0KfQ0KDQovKioNCiAqIEFkZCB0aGUgY29ycmVjdCB2ZXJ0aWNhbCBhbGlnbm1lbnQgaW4gQ2hyb21lLCBGaXJlZm94LCBhbmQgT3BlcmEuDQogKi8NCg0KcHJvZ3Jlc3Mgew0KICB2ZXJ0aWNhbC1hbGlnbjogYmFzZWxpbmU7DQp9DQoNCi8qKg0KICogUmVtb3ZlIHRoZSBkZWZhdWx0IHZlcnRpY2FsIHNjcm9sbGJhciBpbiBJRSAxMCsuDQogKi8NCg0KdGV4dGFyZWEgew0KICBvdmVyZmxvdzogYXV0bzsNCn0NCg0KLyoqDQogKiAxLiBBZGQgdGhlIGNvcnJlY3QgYm94IHNpemluZyBpbiBJRSAxMC4NCiAqIDIuIFJlbW92ZSB0aGUgcGFkZGluZyBpbiBJRSAxMC4NCiAqLw0KDQpbdHlwZT0iY2hlY2tib3giXSwNClt0eXBlPSJyYWRpbyJdIHsNCiAgYm94LXNpemluZzogYm9yZGVyLWJveDsgLyogMSAqLw0KICBwYWRkaW5nOiAwOyAvKiAyICovDQp9DQoNCi8qKg0KICogQ29ycmVjdCB0aGUgY3Vyc29yIHN0eWxlIG9mIGluY3JlbWVudCBhbmQgZGVjcmVtZW50IGJ1dHRvbnMgaW4gQ2hyb21lLg0KICovDQoNClt0eXBlPSJudW1iZXIiXTo6LXdlYmtpdC1pbm5lci1zcGluLWJ1dHRvbiwNClt0eXBlPSJudW1iZXIiXTo6LXdlYmtpdC1vdXRlci1zcGluLWJ1dHRvbiB7DQogIGhlaWdodDogYXV0bzsNCn0NCg0KLyoqDQogKiAxLiBDb3JyZWN0IHRoZSBvZGQgYXBwZWFyYW5jZSBpbiBDaHJvbWUgYW5kIFNhZmFyaS4NCiAqIDIuIENvcnJlY3QgdGhlIG91dGxpbmUgc3R5bGUgaW4gU2FmYXJpLg0KICovDQoNClt0eXBlPSJzZWFyY2giXSB7DQogIC13ZWJraXQtYXBwZWFyYW5jZTogdGV4dGZpZWxkOyAvKiAxICovDQogIG91dGxpbmUtb2Zmc2V0OiAtMnB4OyAvKiAyICovDQp9DQoNCi8qKg0KICogUmVtb3ZlIHRoZSBpbm5lciBwYWRkaW5nIGluIENocm9tZSBhbmQgU2FmYXJpIG9uIG1hY09TLg0KICovDQoNClt0eXBlPSJzZWFyY2giXTo6LXdlYmtpdC1zZWFyY2gtZGVjb3JhdGlvbiB7DQogIC13ZWJraXQtYXBwZWFyYW5jZTogbm9uZTsNCn0NCg0KLyoqDQogKiAxLiBDb3JyZWN0IHRoZSBpbmFiaWxpdHkgdG8gc3R5bGUgY2xpY2thYmxlIHR5cGVzIGluIGlPUyBhbmQgU2FmYXJpLg0KICogMi4gQ2hhbmdlIGZvbnQgcHJvcGVydGllcyB0byBgaW5oZXJpdGAgaW4gU2FmYXJpLg0KICovDQoNCjo6LXdlYmtpdC1maWxlLXVwbG9hZC1idXR0b24gew0KICAtd2Via2l0LWFwcGVhcmFuY2U6IGJ1dHRvbjsgLyogMSAqLw0KICBmb250OiBpbmhlcml0OyAvKiAyICovDQp9DQoNCi8qIEludGVyYWN0aXZlDQogICA9PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PSAqLw0KDQovKg0KICogQWRkIHRoZSBjb3JyZWN0IGRpc3BsYXkgaW4gRWRnZSwgSUUgMTArLCBhbmQgRmlyZWZveC4NCiAqLw0KDQpkZXRhaWxzIHsNCiAgZGlzcGxheTogYmxvY2s7DQp9DQoNCi8qDQogKiBBZGQgdGhlIGNvcnJlY3QgZGlzcGxheSBpbiBhbGwgYnJvd3NlcnMuDQogKi8NCg0Kc3VtbWFyeSB7DQogIGRpc3BsYXk6IGxpc3QtaXRlbTsNCn0NCg0KLyogTWlzYw0KICAgPT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT09PT0gKi8NCg0KLyoqDQogKiBBZGQgdGhlIGNvcnJlY3QgZGlzcGxheSBpbiBJRSAxMCsuDQogKi8NCg0KdGVtcGxhdGUgew0KICBkaXNwbGF5OiBub25lOw0KfQ0KDQovKioNCiAqIEFkZCB0aGUgY29ycmVjdCBkaXNwbGF5IGluIElFIDEwLg0KICovDQoNCltoaWRkZW5dIHsNCiAgZGlzcGxheTogbm9uZTsNCn0NCg=="
echo ${normalize_css} | base64 -d > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/static/normalize.css"

# following HTML5 boilerplate is from https://www.sitepoint.com/a-basic-html5-template/
cat <<EOF > "${ROOT_DIR}/${DJANGO_PROJECT_NAME}/templates/base.html"
{% load static %}

<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8" />
<meta name="viewport" content="width=device-width, initial-scale=1" />

<title>{% block title_tag %}Title Tag{% endblock title_tag %}</title>

<meta name="description" content="" />
<meta name="author" content="" />

<meta property="og:title" content="" />
<meta property="og:type" content="website" />
<meta property="og:url" content="" />
<meta property="og:description" content="" />
<meta property="og:image" content="" />

<link rel="icon" href="{% static "favicon.ico" %}" />
<link rel="icon" href="{% static "favicon.svg" %}" type="image/svg+xml" />
<link rel="apple-touch-icon" href="{% static "apple-touch-icon.png" %}" />
<link rel="stylesheet" href="{% static "normalize.css" %}" />
<link rel="stylesheet" href="{% static "styles.css" %}" />
</head>

<body>
{% block content %}
{% endblock content %}
</body>
</html>

EOF

python manage.py collectstatic --noinput

# create .conf file for Apache
cat <<EOF > "${ROOT_DIR}/apache2_files/${DJANGO_PROJECT_NAME}.conf"

WSGIPythonHome ${ROOT_DIR}/${VENV_NAME}

<VirtualHost *:${WEB_PORT}>
        #ServerName example.com
        #ServerAlias www.example.com

        DocumentRoot /var/www/html

        Alias /static ${ROOT_DIR}/${DJANGO_PROJECT_NAME}/staticfiles

        <Directory ${ROOT_DIR}/${DJANGO_PROJECT_NAME}/staticfiles>
            Require all granted
            AllowOverride All
        </Directory>

        <Directory ${ROOT_DIR}/${DJANGO_PROJECT_NAME}/${DJANGO_PROJECT_NAME}>
            <Files wsgi.py>
                Require all granted
            </Files>
        </Directory>
        
        WSGIDaemonProcess ${DJANGO_PROJECT_NAME}_pg python-home=${ROOT_DIR}/${VENV_NAME} python-path=${ROOT_DIR}/${DJANGO_PROJECT_NAME} threads=15 maximum-requests=10000
        WSGIProcessGroup ${DJANGO_PROJECT_NAME}_pg
        WSGIScriptAlias / ${ROOT_DIR}/${DJANGO_PROJECT_NAME}/${DJANGO_PROJECT_NAME}/wsgi.py process-group=${DJANGO_PROJECT_NAME}_pg

        #LogLevel info ssl:warn

        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined

</VirtualHost>

EOF

# tell Apache2 to listen on the specified port, if necessary
if [ "${WEB_PORT}" != "80" ]; then
cat <<EOF | sudo tee -a /etc/apache2/ports.conf > /dev/null

Listen 127.0.0.1:${WEB_PORT}

EOF
fi

# ensite the project's Apache .conf file and reload Apache
sudo ln -s "${ROOT_DIR}/apache2_files/${DJANGO_PROJECT_NAME}.conf" /etc/apache2/sites-enabled

if [[ "${DISSITE_DEFAULT}" == "true" ]]; then
    sudo a2dissite 000-default.conf
fi

yes | sudo ufw enable
sudo ufw allow "${WEB_PORT}"
sudo systemctl reload apache2

# setup VS Code settings
mkdir "${ROOT_DIR}/.vscode"
cat <<EOF >> "${ROOT_DIR}/.vscode/settings.json"

{
    "python.defaultInterpreterPath": "${ROOT_DIR}/${VENV_NAME}/bin/python3",
    "python.terminal.activateEnvironment": true,
    "files.associations": {
        "**/*.html": "html",
        "**/templates/**/*.html": "django-html",
        "**/templates/**/*": "django-txt",
        "**/requirements{/**,*}.{txt,in}": "pip-requirements",
        },
    "[django-html]": {
      "editor.defaultFormatter": "monosans.djlint"
    },
    "[html]": {
      "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "[css]": {
      "editor.defaultFormatter": "esbenp.prettier-vscode"
    },
    "emmet.triggerExpansionOnTab": true,
    "emmet.useInlineCompletions": true,
    "emmet.includeLanguages": {
        "django-html": "html"
    },

    "djlint.useVenv": true
}

EOF

cat <<EOF >> "${ROOT_DIR}/.vscode/extensions.json"

{
    "recommendations": [
        "batisteo.vscode-django",
        "esbenp.prettier-vscode",
        "monosans.djlint",
        "ms-python.python",
        "ms-python.vscode-pylance"
    ]
}

EOF

# wrap up

ls -al "${ROOT_DIR}"

ls -al "${ROOT_DIR}/${DJANGO_PROJECT_NAME}"

cat <<EOF
*
* Possible next steps:
*     sudo ufw allow 8000
*     cd ${ROOT_DIR} && source ./${VENV_NAME}/bin/activate
*     cd ${ROOT_DIR}/${DJANGO_PROJECT_NAME}
*     python manage.py createsuperuser
*     python manage.py runserver 0.0.0.0:8000
*
* Output of 'hostname -I': $(hostname -I)
*
* Possible VS Code extensions to install:
*     prettier, python, django, djlint

EOF

