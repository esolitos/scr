#!/usr/bin/env sh
if [ ! -z "${DEBUG:-}" ]; then
  set -x
fi


BKP_DATE="$(date '+%Y-%W')"
BKP_DIR='/var/backups/mysql'
B2_BUCKET='com-esolitos-host'

mkdir -p "$BKP_DIR/$BKP_DATE"
for dbname in $(mysql --defaults-file=/etc/mysql/debian.cnf --local-infile --batch --skip-column-names -e "SHOW DATABASES;" | grep -vE '(performance_schema|information_schema|mysql)'); do
  mysqldump --defaults-file=/etc/mysql/debian.cnf --add-drop-table --add-locks --comments --flush-privileges --lock-all-tables --dump-date "$dbname" | pigz -c > "$BKP_DIR/$BKP_DATE/$dbname.sql.gz"
done;

/usr/local/bin/b2 sync --keepDays 120 --noProgress "$BKP_DIR/$BKP_DATE" "b2://${B2_BUCKET}/mysql/" 
if [ $? -ne 0 ]; then
  printf "ERROR: Backups not uploaded!\n" 1>&2
  exit 10
fi

