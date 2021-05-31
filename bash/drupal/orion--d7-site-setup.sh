#!/bin/bash

VHOST_PATH='/var/www/vhosts'
FILES_BASE='/var/www/files'
CONF_PATH='/var/www/vhosts/conf'

NGINX_PATH='/etc/nginx'

# VHOST_PATH='./TmpBin/vhosts'
# FILES_BASE='./TmpBin/files'
# CONF_PATH='.'

if [[ -z $1 ]]; then
  echo "Missing hostname!!!"
  exit
fi

SITE_DOMAIN="$1"

if [[ -z "$2" ]]; then
  REPO_URL="esolitos@bitbucket.org:esolitos/$SITE_DOMAIN.git"
else
  REPO_URL="$2"
fi

DB_USER="$(echo "$SITE_DOMAIN"| tr -cd '[:alpha:]' | cut -c 1-16)"
DB_NAME="drupal_$DB_USER"
DB_PASS="$(/usr/bin/openssl rand -hex 16)"

DRUPAL_SALT="`/usr/bin/openssl rand -hex 32`"

echo -e "\n### Add the key to: https://bitbucket.org/esolitos/$SITE_DOMAIN/admin/access-keys/  ###\n"
cat "$VHOST_PATH/.ssh/id_rsa.pub"
echo -e "\n### ENDKEY ###"
read -p "Press 'enter' once you're done."

# Get the code
git clone "$REPO_URL" "$VHOST_PATH/$SITE_DOMAIN"

if [ $? -ne 0 ]; then
  echo "Error in git clone. Aborting." 1>&2
  exit 1;
fi

echo "Create files directories..."
mkdir -p "$FILES_BASE/$SITE_DOMAIN/public" "$FILES_BASE/$SITE_DOMAIN/private"
chown -R www-data:www-data "$FILES_BASE/$SITE_DOMAIN"

echo "Link public files directory..."
ln -s "$FILES_BASE/$SITE_DOMAIN/public" "$VHOST_PATH/$SITE_DOMAIN/web/sites/default/files"

### MySQL

echo "Create user, db and grant permissions."
echo "CREATE DATABASE $DB_NAME;\
FLUSH PRIVILEGES;\
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'" | mysql -u'root' -p"$MARIA_ROOT_PASS"

if [ $? -ne 0 ]; then
  echo "Error in MySQL setup step. Aborting." 1>&2
  exit 2;
fi

echo "Configure settings.php with generated data..."

sed "s/TPL_site_domain/$SITE_DOMAIN/g;\
s/TPL_hash_salt/$DRUPAL_SALT/g;\
s/TPL_db_name/$DB_NAME/g;\
s/TPL_db_user/$DB_USER/g;\
s/TPL_db_pass/$DB_PASS/g;" "$CONF_PATH/tpl.settings-d7.php" > "$VHOST_PATH/$SITE_DOMAIN/web/sites/default/settings.php"


### nginx

echo "Configuring nginx servers..."
sed "s/THE_HOSTNAME/$SITE_DOMAIN/g;\
s/#{NO_VARNISH}//g;\
s/#{D7}//g;" "$NGINX_PATH/sites-available/TEMPLATE-DRUPAL.conf" > "$NGINX_PATH/sites-available/$SITE_DOMAIN.conf"

echo -e "### NGINX CONF: $NGINX_PATH/sites-available/$SITE_DOMAIN.conf ###\n"
cat "$NGINX_PATH/sites-available/$SITE_DOMAIN.conf"
echo "\n### END CONF ###"
read -p "Check the nginx config and press 'enter' once you're ok."

echo "Enabling site..."
ln -s "../sites-available/$SITE_DOMAIN.conf" "$NGINX_PATH/sites-enabled/$SITE_DOMAIN.conf"
ls -l "$NGINX_PATH/sites-enabled/"

echo "Reloading nginx configuration..."
nginx -s reload

echo "Completed!!\n\tTest the site: http://$SITE_DOMAIN"
