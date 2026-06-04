#!/bin/bash
set -e # Exit immediately if a command exits with a non-zero status

# 1. Provision users first while the system is quiet
echo "-------- Provisioning Linux users --------"
/usr/local/bin/init_user.sh /usr/local/bin/sysad-1-users.yaml

# 2. Wait for MySQL
DB_HOST="db"
DB_USER="blog_user"
DB_PASS="blogpass"
until mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" -e "SELECT 1;" >/dev/null 2>&1; do
  echo "--------Waiting for MySQL--------"
  sleep 2
done
echo "--------MySQL is ready.--------"

# 3. Setup database tables
/usr/local/bin/databaseSetup.sh

# 4. Start SSHD in the foreground as the final, blocking process
echo "-------- Starting SSH Server --------"
exec /usr/sbin/sshd -D
