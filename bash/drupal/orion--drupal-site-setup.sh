#!/bin/bash

VHOST_PATH='/var/www/vhosts'
FILES_BASE='/var/www/files'
CONF_PATH='/var/www/vhosts/conf'

NGINX_PATH='/etc/nginx'

MY_PAW='armpit blowy hiatus teasel trickery toughen gladsome diarist reality dog'

# Runs a command (arg2) as another user (arg1)
run_as() {
  AS_USER="$1"
  su -l -s/bin/bash "$AS_USER" -c"$2"

  if [ $? -ne 0 ]; then
    echo "Error running as '$AS_USER', command: $2" 1>&2
    exit -1
  fi
}

if [[ -z $1 ]]; then
  echo "Missing hostname!!!"
  exit 1
fi

DRUPAL_VERSION="$1"
SITE_DOMAIN="$2"
if [[ -z "$3" ]]; then
  REPO_URL="esolitos@bitbucket.org:esolitos/$SITE_DOMAIN.git"
else
  REPO_URL="$3"
fi

if [ "$DRUPAL_VERSION" != 'D8' -a "$DRUPAL_VERSION" != 'D7' ]; then
  echo "Drupal version must be either D7 or D8. Received: $DRUPAL_VERSION" 1>&2
  exit 2
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
run_as 'hosting' "git clone $REPO_URL $VHOST_PATH/$SITE_DOMAIN"

# Run composer
if [ -f "$VHOST_PATH/$SITE_DOMAIN/composer.lock" ]; then
  run_as 'hosting' "composer --no-interaction --no-dev --optimize-autoloader --no-progress --working-dir=$VHOST_PATH/$SITE_DOMAIN install"
fi

echo "Creaate files directories..."
run_as 'www-data' "mkdir -p $FILES_BASE/$SITE_DOMAIN/{public,private}"
# chown -R www-data:www-data "$FILES_BASE/$SITE_DOMAIN"

echo "Link public files directory..."
ln -s "$FILES_BASE/$SITE_DOMAIN/public" "$VHOST_PATH/$SITE_DOMAIN/web/sites/default/files"

### MySQL
if [ $(mysql -p"$MY_PAW" --skip-column-names --silent -e"SHOW DATABASES LIKE '$DB_NAME';" | wc -l) -gt 0 ]; then
  read -p "Database exists, do you want to drop it (y/N)? " yn
  if [ "$yn" = 'y' -o "$yn" = 'Y' ]; then
    read -p "Dropping $DB_NAME. Press [enter] to confirm."
    mysql -p"$MY_PAW" -e"DROP DATABASE $DB_NAME;"
  else
    echo "Aborting: Database exist and will not be dropped." 1>&2
    exit 100
  fi
fi

echo "Create user, db and grant permissions."
echo "CREATE DATABASE $DB_NAME;\
GRANT ALL PRIVILEGES ON $DB_NAME.* TO '$DB_USER'@'localhost' IDENTIFIED BY '$DB_PASS'" | mysql -p"$MY_PAW"

if [ $? -ne 0 ]; then
  echo "Error in MySQL setup step. Aborting." 1>&2
  exit 3;
fi

echo "Configure settings.php with generated data..."

sed "s/TPL_site_domain/$SITE_DOMAIN/g;\
s/TPL_hash_salt/$DRUPAL_SALT/g;\
s/TPL_db_name/$DB_NAME/g;\
s/TPL_db_user/$DB_USER/g;\
s/TPL_db_pass/$DB_PASS/g;" "$CONF_PATH/tpl.settings-$DRUPAL_VERSION.php" > "$VHOST_PATH/$SITE_DOMAIN/web/sites/default/settings.php"


### nginx

echo "Configuring nginx servers..."
sed "s/#{$DRUPAL_VERSION}//g;\
s/THE_HOSTNAME/$SITE_DOMAIN/g;\
s/#{NO_VARNISH}//g;" "$NGINX_PATH/sites-available/TEMPLATE-DRUPAL.conf" > "$NGINX_PATH/sites-available/$SITE_DOMAIN.conf"

echo -e "### NGINX CONF: $NGINX_PATH/sites-available/$SITE_DOMAIN.conf ###\n"
cat "$NGINX_PATH/sites-available/$SITE_DOMAIN.conf"
echo "\n### END CONF ###"
read -p "Check the nginx config and press 'enter' once you're ok."

echo "Enabling site..."
ln -s "../sites-available/$SITE_DOMAIN.conf" "$NGINX_PATH/sites-enabled/$SITE_DOMAIN.conf"
ls -l "$NGINX_PATH/sites-enabled/"

echo "Reloading nginx configuration..."
nginx -s reload

echo -e "Completed!!\n\tTest the site: http://$SITE_DOMAIN"
