#!/bin/bash
# Starts up the Phabricator stack within the container.

# Stop on error
#set -e

LDAP_HOST="${LDAP_HOST}"
LDAP_BASE_DN="${LDAP_BASE_DN}"
LDAP_LOGIN_DN="${LDAP_LOGIN_DN}"
LDAP_SERVER_NAME="${LDAP_SERVER_NAME}"

echo "LDAP_HOST = $LDAP_HOST"
echo "LDAP_BASE_DN = $LDAP_BASE_DN"
echo "LDAP_LOGIN_DN = $LDAP_LOGIN_DN"
echo "LDAP_SERVER_NAME = $LDAP_SERVER_NAME"
echo "LDAP_TLS_CA_NAME = ${LDAP_TLS_CA_NAME}"

PHPLDAPADMIN_SSL_CRT_FILENAME=${PHPLDAPADMIN_SSL_CRT_FILENAME}
PHPLDAPADMIN_SSL_KEY_FILENAME=${PHPLDAPADMIN_SSL_KEY_FILENAME}

if [[ -e /first_run ]]; then
  source /scripts/first_run.sh
else
  source /scripts/normal_run.sh
fi

pre_start_action
post_start_action

exec supervisord
