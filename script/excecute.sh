#!/bin/bash

/usr/local/bin/init_user.sh /usr/local/bin/sysad-1-users.yaml

DB_HOST="db"
DB_USER="blog_user"
DB_PASS="blogpass"


until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; do
  echo "--------Waiting for MySQL--------"
  sleep 2
done

echo "--------MySQL is ready.--------"

/usr/local/bin/databaseSetup.sh

tail -f /dev/null

