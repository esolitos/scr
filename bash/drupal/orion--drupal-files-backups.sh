#!/bin/sh
BKP_DATE="$(date '+%Y-%W')"
BKP_DIR='/var/backups/drupal-files'
SITES_FILES_ROOT='/var/www/files'
B2_BUCKET='com-esolitos-host'

mkdir -p "$BKP_DIR/$BKP_DATE" || exit 1;
cd "$SITES_FILES_ROOT" || exit 2

for SITENAME in $(ls $SITES_FILES_ROOT); do
  echo "Backup $SITENAME\t=>\t$BKP_DIR/$BKP_DATE/$SITENAME.tar.gz"
  tar -c -I /usr/bin/pigz --preserve-permissions --xattrs --acls -f "$BKP_DIR/$BKP_DATE/$SITENAME.tar.gz" "$SITENAME/"
done


/usr/local/bin/b2 sync --keepDays 120 --noProgress "$BKP_DIR/$BKP_DATE" "b2://${B2_BUCKET}/drupal-files/"
if [ $? -ne 0 ]; then
  printf "ERROR: Backups not uploaded!\n" 1>&2
  exit 10
fi

