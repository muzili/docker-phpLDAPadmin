pre_start_action() {
    mkdir -p $LOG_DIR

    echo "configuring LDAP for first run"
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

    rm -rf /etc/nginx/sites-enabled/*
    cat >/etc/nginx/sites-enabled/phpldapadmin.conf <<EOF
## This is a normal HTTP host which redirects all traffic to the HTTPS host.
server {
  listen 80;
  server_name  $LDAPADMIN_SERVER_NAME;
  root /usr/share/phpldapadmin/htdocs;
  index index.html index.htm index.php;

  #pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
  location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
    #With php5-cgi alone:
    #fastcgi_pass 127.0.0.1:9000;
    #With php5-fpm:
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
  }
}
server {
  listen 443;
  server_name  $LDAPADMIN_SERVER_NAME;
  root /usr/share/phpldapadmin/htdocs;
  index index.html index.htm index.php;

  #pass the PHP scripts to FastCGI server listening on 127.0.0.1:9000
  location ~ \.php$ {
    fastcgi_split_path_info ^(.+\.php)(/.+)$;
    #NOTE: You should have "cgi.fix_pathinfo = 0;" in php.ini
    #With php5-cgi alone:
    #fastcgi_pass 127.0.0.1:9000;
    #With php5-fpm:
    fastcgi_pass unix:/var/run/php5-fpm.sock;
    fastcgi_index index.php;
    include fastcgi_params;
  }

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

  # logging
  error_log $LOG_DIR/nginx/error.log;
  access_log $LOG_DIR/nginx/access.log;
}
EOF
    mkdir -p $LOG_DIR/nginx
    mkdir -p /etc/nginx/ssl
    openssl req -x509 -nodes -days 3650 -newkey rsa:2048 -subj "/C=CN/ST=SH/L=SHANGHAI/O=MoreTV/OU=Helios/CN=muzili@gmail.com"  -keyout /etc/nginx/ssl/phpldapadmin.key -out /etc/nginx/ssl/phpldapadmin.crt

    cat > /etc/php-fpm.conf <<EOF
[global]
pid = /run/php-fpm/php-fpm.pid
error_log = $LOG_DIR/php-fpm/error.log
daemonize = no
[www]
user = nginx
group = nginx
listen = /var/run/php-fpm/www.sock
listen.owner = nginx
listen.group = nginx
listen.mode = 0666
pm = dynamic
pm.max_children = 4
pm.start_servers = 2
pm.min_spare_servers = 1
pm.max_spare_servers = 4
catch_workers_output = yes
php_admin_value[error_log] = $LOG_DIR/php-fpm/phabricator.php.log
php_admin_value[sendmail_path] = /usr/bin/msmtp -t -C /etc/msmtprc
EOF
    touch /etc/msmtprc
    mkdir -p $LOG_DIR/msmtp
    chown nginx:nginx $LOG_DIR/msmtp
    cat > /etc/msmtprc <<EOF
# The SMTP server of the provider.
defaults
logfile $LOG_DIR/msmtp/msmtplog

account mail
host $SMTP_HOST
port $SMTP_PORT
user $SMTP_USER
password $SMTP_PASS
auth login
tls on
tls_trust_file /etc/pki/tls/certs/ca-bundle.crt

account default : mail

EOF
    chmod 600 /etc/msmtprc

    cat > /etc/supervisord.conf <<-EOF
[unix_http_server]
file=/run/supervisor.sock   ; (the path to the socket file)

[supervisord]
logfile=$LOG_DIR/supervisor/supervisord.log ; (main log file;default $CWD/supervisord.log)
logfile_maxbytes=50MB       ; (max main logfile bytes b4 rotation;default 50MB)
logfile_backups=10          ; (num of main logfile rotation backups;default 10)
loglevel=info               ; (log level;default info; others: debug,warn,trace)
pidfile=/run/supervisord.pid ; (supervisord pidfile;default supervisord.pid)
nodaemon=true               ; (start in foreground if true;default false)
minfds=1024                 ; (min. avail startup file descriptors;default 1024)
minprocs=200                ; (min. avail process descriptors;default 200)

[rpcinterface:supervisor]
supervisor.rpcinterface_factory = supervisor.rpcinterface:make_main_rpcinterface

[supervisorctl]
serverurl=unix:///run/supervisor.sock ; use a unix:// URL  for a unix socket

[include]
files = /etc/supervisor/conf.d/*.conf
EOF
    cat > /etc/supervisor/conf.d/ldapadmin.conf <<-EOF
[program:php5-fpm]
command=/usr/sbin/php5-fpm --nodaemonize

[program:nginx]
command=/usr/sbin/nginx

EOF

    chown -R nginx:nginx "$LOG_DIR/nginx"
}

post_start_action() {
    rm /first_run
}
