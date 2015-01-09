#!/bin/sh

# -e Exit immediately if a command exits with a non-zero status
set -e

status () {
  echo "---> ${@}" >&2
}

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

if [ ! -e /etc/phpldapadmin/docker_bootstrapped ]; then
  status "configuring LDAP for first run"

  if [ -e /etc/ldap/ssl/ca.crt ]; then
    # LDAP  CA
    sed -i "s/TLS_CACERT.*/TLS_CACERT       \/etc\/ldap\/ssl\/ca.crt/g" /etc/ldap/ldap.conf
    sed -i '/TLS_CACERT/a\TLS_CIPHER_SUITE        HIGH:MEDIUM:+SSLv3' /etc/ldap/ldap.conf
    # phpLDAPadmin use tls
    sed -i "s/.*'server','tls'.*/\$servers->setValue('server','tls',true);/g" /etc/phpldapadmin/config.php
  fi

  # phpLDAPadmin config
  sed -i "s/'127.0.0.1'/'${LDAP_HOST}'/g" /etc/phpldapadmin/config.php
  sed -i "s/'dc=example,dc=com'/'${LDAP_BASE_DN}'/g" /etc/phpldapadmin/config.php
  sed -i "s/'cn=admin,dc=example,dc=com'/'${LDAP_LOGIN_DN}'/g" /etc/phpldapadmin/config.php
  sed -i "s/'My LDAP Server'/'${LDAP_SERVER_NAME}'/g" /etc/phpldapadmin/config.php

  # Fix the bug with password_hash
  # See http://stackoverflow.com/questions/20673186/getting-error-for-setting-password-feild-when-creating-generic-user-account-phpl
  sed -i "s/'password_hash'/'password_hash_custom'/" /usr/share/phpldapadmin/lib/TemplateRender.php

  # Hide template warnings
  sed -i "s:// \$config->custom->appearance\['hide_template_warning'\] = false;:\$config->custom->appearance\[\'hide_template_warning\'\] = true;:g" /etc/phpldapadmin/config.php

  rm /etc/nginx/sites-enabled/*
  cat >/etc/nginx/sites-enabled/phpldapadmin.conf <<EOF
## This is a normal HTTP host which redirects all traffic to the HTTPS host.
location ~ \.php$ {
   fastcgi_split_path_info ^(.+\.php)(/.+)$;
   # NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini

   fastcgi_pass unix:/var/run/php5-fpm.sock;
   fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
   fastcgi_index index.php;
   include fastcgi_params;
}


server {
  listen *:80;
  server_name  $LDAPADMIN_SERVER_NAME;
  root /usr/share/phpldapadmin/htdocs;
  index index.html index.htm index.php;
}

server {
  listen 443 ssl spdy;
  listen [::]:443 ssl spdy;

  server_name  $LDAPADMIN_SERVER_NAME;

  root /usr/share/phpldapadmin/htdocs;
  index index.html index.htm index.php;

  ## SSL Security
  ## https://raymii.org/s/tutorials/Strong_SSL_Security_On_nginx.html
  ssl on;
  ssl_certificate /etc/nginx/ssl/phpldapadmin.crt;
  ssl_certificate_key /etc/nginx/ssl/phpldapadmin.key;

  ssl_ciphers 'ECDHE-RSA-AES256-GCM-SHA384:ECDHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384:DHE-RSA-AES128-GCM-SHA256:ECDHE-RSA-AES256-SHA384:ECDHE-RSA-AES128-SHA256:ECDHE-RSA-AES256-SHA:ECDHE-RSA-AES128-SHA:DHE-RSA-AES256-SHA256:DHE-RSA-AES128-SHA256:DHE-RSA-AES256-SHA:DHE-RSA-AES128-SHA:ECDHE-RSA-DES-CBC3-SHA:EDH-RSA-DES-CBC3-SHA:AES256-GCM-SHA384:AES128-GCM-SHA256:AES256-SHA256:AES128-SHA256:AES256-SHA:AES128-SHA:DES-CBC3-SHA:HIGH:!aNULL:!eNULL:!EXPORT:!CAMELLIA:!DES:!MD5:!PSK:!RC4';

  ssl_protocols  TLSv1 TLSv1.1 TLSv1.2;
  ssl_session_cache  builtin:1000  shared:SSL:10m;

  ssl_prefer_server_ciphers   on;

  add_header Strict-Transport-Security max-age=63072000;
  add_header X-Frame-Options DENY;
  add_header X-Content-Type-Options nosniff;
}
EOF
  openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -subj "/C=CN/ST=SH/L=SHANGHAI/O=MoreTV/OU=Helios/CN=muzili@gmail.com"  -keyout /etc/nginx/ssl/phpldapadmin.key -out /etc/nginx/ssl/phpldapadmin.crt
  touch /etc/phpldapadmin/docker_bootstrapped
