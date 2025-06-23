#!/bin/bash

echo "-------- Sleeping for 300 seconds to wait for user setup --------"
sleep 300


mkdir -p /update_scripts
echo "#!/bin/bash" > /update_scripts/update_etc.sh
echo "" >> /update_scripts/update_etc.sh

for user in $(ls /home/authors); do
    echo "echo \"127.0.0.1 ${user}.blog.in\" >> /etc/hosts" >> /update_scripts/update_etc.sh
done

chmod +x /update_scripts/update_etc.sh


cat <<EOF > /etc/nginx/nginx.conf
user nginx;
worker_processes auto;

events {
    worker_connections 1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;

    server {
        listen 80 default_server;
        server_name _;
        return 404;
    }
EOF

for user in $(ls /home/authors); do
cat <<EOF >> /etc/nginx/nginx.conf

    server {
        listen 80;
        server_name ${user}.blog.in;

        location / {
            root /home/authors/${user}/public;
            autoindex on;
        }
    }
EOF
done

echo "}" >> /etc/nginx/nginx.conf

echo "-------- Starting Nginx right now--------"
exec nginx -g 'daemon off;'
