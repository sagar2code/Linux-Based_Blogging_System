#!/bin/bash

DB="blogsys"
USER="blog_user"
PASS="${MYSQL_PASSWORD:-blogpass}"
HOST="db"

echo "-------- Waiting for MySQL to be ready --------"
until mysql -h "$HOST" -u "$USER" -p"$PASS" -e "SELECT 1;" "$DB" >/dev/null 2>&1; do
    echo "  MySQL not ready yet, retrying in 3s..."
    sleep 3
done
echo "-------- MySQL is ready --------"

echo "-------- Creating blog tables for authors --------"

for author in $(ls /home/authors); do
    echo " Creating table for $author"
    mysql -h "$HOST" -u "$USER" -p"$PASS" "$DB" -e "
        CREATE TABLE IF NOT EXISTS \`${author}_blogs\` (
            filename     VARCHAR(255) PRIMARY KEY,
            publish_status VARCHAR(20),
            cat_order    VARCHAR(255)
        );
    "
done

echo "-------- All author tables created. --------"
