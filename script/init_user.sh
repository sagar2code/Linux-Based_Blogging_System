#!/bin/bash

if [ "$(id -u)" -ne 0 ]
then
    echo "This script must be run as root, please use sudo" 		
    exit 1
fi


[ -f /storage/passwd ] && cp /storage/passwd /etc/passwd
[ -f /storage/shadow ] && cp /storage/shadow /etc/shadow
[ -f /storage/group ]  && cp /storage/group  /etc/group


YAML_FILE=$1

echo "Setting up base directory structure and groups"
mkdir -p /home/users
chmod 755 /home/users

mkdir -p /home/authors
chmod 755 /home/authors

mkdir -p /home/mods
chmod 755 /home/mods

mkdir -p /home/admins
chmod 755 /home/admins

if ! getent group g_user &>/dev/null; then
    groupadd g_user 
fi

if ! getent group g_author &>/dev/null; then
    groupadd g_author 
fi

if ! getent group g_mod &>/dev/null; then
    groupadd g_mod 
fi

if ! getent group g_admin &>/dev/null; then
    groupadd g_admin 
fi

create_user() {
 username="$1"
 user_type="$2"
    
    if id "$username" &>/dev/null; then
        echo "User $username exists. Updating right now"
        usermod -G "g_$user_type" $username
        return
    fi

    useradd -m -d "/home/${user_type}s/${username}" -s /bin/bash -G "g_$user_type" "$username"
    echo "$username:DeltaInductions" | chpasswd
    chage -d 0 "$username"
    
    case "$user_type" in
    author)
        mkdir -p "/home/authors/$username"/blogs
        mkdir -p "/home/authors/$username"/public
        chown -R "$username:$username" "/home/authors/$username"
        chmod 751 "/home/authors/$username"
        chmod 755 "/home/authors/$username/public"


        ;;
    mod)
        mkdir -p "/home/mods/$username"/managed_authors
        chown -R "$username:$username" "/home/mods/$username"
        chmod 750 "/home/mods/$username"
        ;;
    user)
        mkdir -p "/home/users/$username"/all_blogs
        chown -R "$username:$username" "/home/users/$username"
        chmod 750 "/home/users/$username"
        ;;
    admin)
        mkdir -p "/home/admins/$username"
        chown -R "$username:$username" "/home/admins/$username"
        chmod 700 "/home/admins/$username"
        ;;
    *)
        echo "Error: Invalid user type '$user_type'" >&2
        exit 1
        ;;
esac
    echo "Created $user_type $username "
}


echo "Processing admins"
if yq e '.admins' "$YAML_FILE" >/dev/null; then
    admin_count=$(yq e '.admins | length' "$YAML_FILE")
    for ((i=0; i<admin_count; i++)); do
        username=$(yq e ".admins[$i].username" "$YAML_FILE")
        create_user "$username" "admin"
    done
fi




echo "Processing users"
if yq e '.users' "$YAML_FILE" >/dev/null; then
    user_count=$(yq e '.users | length' "$YAML_FILE")
    for ((i=0; i<user_count; i++)); do
        username=$(yq e ".users[$i].username" "$YAML_FILE")
        create_user "$username" "user"
    done
fi


echo "Processing authors"
if yq e '.authors' "$YAML_FILE" >/dev/null; then
    author_count=$(yq e '.authors | length' "$YAML_FILE")
    for ((i=0; i<author_count; i++)); do
        username=$(yq e ".authors[$i].username" "$YAML_FILE")
        create_user "$username" "author"
    done
fi


echo "Processing moderators and their author assignments"
if yq e '.mods' "$YAML_FILE" >/dev/null; then
    mod_count=$(yq e '.mods | length' "$YAML_FILE")
    for ((i=0; i<mod_count; i++)); do
        username=$(yq e ".mods[$i].username" "$YAML_FILE")
        create_user "$username" "mod"
        rm -f "/home/mods/$username/managed_authors"/*

        author_usernames=$(yq e ".mods[$i].authors[]" "$YAML_FILE")
        for author in $author_usernames; do
            if ! id "$author" &>/dev/null; then
                echo "Warning: Author $author doesn't exist (assigned to mod $username)"
                continue
            fi

            ln -sfn "/home/authors/$author/public" "/home/mods/$username/managed_authors/$author"
            setfacl -Rm "u:$username:rwX" "/home/authors/$author"
            setfacl -Rdm "u:$username:rwX" "/home/authors/$author"
        done
    done
fi



echo "Setting up all_blogs directory for users... This may take a few minutes, Please wait...."
user_count=$(yq e '.users | length' "$YAML_FILE")
for ((i=0; i<user_count; i++)); do
    username=$(yq e ".users[$i].username" "$YAML_FILE")
    
    rm -f "/home/users/$username/all_blogs"/*
    
 
    author_count=$(yq e '.authors | length' "$YAML_FILE")
    for ((j=0; j<author_count; j++)); do
        author=$(yq e ".authors[$j].username" "$YAML_FILE")
        if [ -d "/home/authors/$author/public" ]; then
            ln -sf "/home/authors/$author/public" "/home/users/$username/all_blogs/$author"
        fi
    done
    
    chown "$username:$username" "/home/users/$username/all_blogs"
    chmod 755 "/home/users/$username/all_blogs"
done



echo "Setting admin privileges"
admin_count=$(yq e '.admins | length' "$YAML_FILE")
author_count=$(yq e '.authors | length' "$YAML_FILE")

for ((i=0; i<admin_count; i++)); do
    admin=$(yq e ".admins[$i].username" "$YAML_FILE")

    admin_access_dir="/home/admins/$admin/admin_access"
    mkdir -p "$admin_access_dir"

    ln -sfn /home/users "$admin_access_dir/users"
    ln -sfn /home/authors "$admin_access_dir/authors"
    ln -sfn /home/mods "$admin_access_dir/moderators"

    chown -R "$admin:$admin" "$admin_access_dir"
    chmod 700 "$admin_access_dir"

    setfacl -R -m "u:$admin:rwx" /home/users
    setfacl -R -m "u:$admin:rwx" /home/authors
    setfacl -R -m "u:$admin:rwx" /home/mods

    setfacl -R -d -m "u:$admin:rwx" /home/users
    setfacl -R -d -m "u:$admin:rwx" /home/authors
    setfacl -R -d -m "u:$admin:rwx" /home/mods

  
    for ((j=0; j<author_count; j++)); do
        author=$(yq e ".authors[$j].username" "$YAML_FILE")
        author_dir="/home/authors/$author"

       
        setfacl -Rm "u:$admin:rwx" "$author_dir"
        setfacl -Rdm "u:$admin:rwx" "$author_dir"

    done
done


#THIS IS FOR THE FIFTH SUBTASK (AdminPanel)


LOG_FILE="/var/log/blog_reads.log"
LOG_SCRIPT="/usr/local/bin/log_cat.sh"


if [ ! -f "$LOG_FILE" ]; then
    touch "$LOG_FILE"
    chmod 664 "$LOG_FILE"  
fi


author_count=$(yq e '.authors | length' "$YAML_FILE")
for ((i=0; i<author_count; i++)); do
    author=$(yq e ".authors[$i].username" "$YAML_FILE")
    setfacl -m u:"$author":rw "$LOG_FILE"
done

admin_count=$(yq e '.admins | length' "$YAML_FILE")
for ((i=0; i<admin_count; i++)); do
    admin=$(yq e ".admins[$i].username" "$YAML_FILE")
    setfacl -m u:"$admin":r "$LOG_FILE"
done

if [ ! -f "$LOG_SCRIPT" ]; then
    cat <<EOF > "$LOG_SCRIPT"
#!/bin/bash
echo "\$(basename \"\$1\")" >> "$LOG_FILE"
/bin/cat "\$1"
EOF
    chmod +x "$LOG_SCRIPT"
    echo "Created log_cat.sh script at $LOG_SCRIPT"
fi


for ((i=0; i<author_count; i++)); do
    author=$(yq e ".authors[$i].username" "$YAML_FILE")
    author_home="/home/authors/$author"
    bashrc_file="$author_home/.bashrc"

    if [ ! -f "$bashrc_file" ]; then
        touch "$bashrc_file"
        chown "$author":"$author" "$bashrc_file"
    fi

    if ! grep -q "alias cat=" "$bashrc_file"; then
        echo "" >> "$bashrc_file"
        echo "alias cat='$LOG_SCRIPT'" >> "$bashrc_file"
        
    fi
done

mkdir -p "/storage"

cp /etc/passwd /storage/passwd
cp /etc/shadow /storage/shadow
cp /etc/group  /storage/group


echo "User setup completed successfully."





