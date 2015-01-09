FROM muzili/centos-php
MAINTAINER Joshua Lee <muzili@gmail.com>

# Default configuration: can be overridden at the docker command line
ENV LDAP_HOST 127.0.0.1
ENV LDAP_BASE_DN dc=example,dc=com
ENV LDAP_LOGIN_DN cn=admin,dc=example,dc=com
ENV LDAP_SERVER_NAME ldap.example.com
ENV LDAPADMIN_SERVER_NAME ldapadmin.example.com

# phpLDAPadmin SSL certificat and private key filename
ENV PHPLDAPADMIN_SSL_CRT_FILENAME phpldapadmin.crt
ENV PHPLDAPADMIN_SSL_KEY_FILENAME phpldapadmin.key

# LDAP CA certificat filename
ENV LDAP_TLS_CA_NAME ca.crt

# Add scripts
ADD scripts /scripts

# Resynchronize the package index files from their sources
RUN yum install -y phpldapadmin.noarch

# Expose http and https default ports
EXPOSE 80 443

CMD ["/scripts/start.sh"]
