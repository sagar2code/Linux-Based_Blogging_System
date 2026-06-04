#!/bin/bash

echo "-------- Sleeping for 45 seconds to wait for MySQL and user setup --------"
sleep 45

DB="blogsys"
USER="blog_user"
PASS="blogpass"
HOST="db"

echo "-------- Creating blog tables for authors --------"

for author in $(ls /home/authors); do
  echo " Creating table for $author"

  mysql -h "$HOST" -u "$USER" -p"$PASS" "$DB" -e "
    CREATE TABLE IF NOT EXISTS ${author}_blogs (
      filename VARCHAR(255),
      publish_status VARCHAR(20),
      cat_order VARCHAR(255)
    );
  "
done

echo "--------All author tables created.--------"

