#!/bin/bash

author_name=`whoami`

if ! id -nG | grep -qw "g_author"; then
    echo "Error: Current user must be an author"
    exit 1
fi

DB_HOST="db"
DB_USER="blog_user"
DB_PASS="blogpass"
DB_NAME="blogsys"
TABLE="${author_name}_blogs"


execute_sql_prepared() {
  local stmt="$1"
  mysql -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" \
    --execute="$stmt" 2>/dev/null
}

sanitize() {
  # Escape single quotes by doubling them (SQL standard)
  printf '%s' "$1" | sed "s/'/''/g"
}


#hello'); DROP TABLE author_blogs; -- 

# INSERT INTO author_blogs (filename, publish_status, cat_order)
#VALUES ('hello'); DROP TABLE author_blogs; -- ', 'TRUE', '1,2');

BLOGS_DIR="/home/authors/$author_name/blogs"
AUTHOURS_DIR="/home/authors/$author_name"
PUBLIC_DIR="/home/authors/$author_name/public"

if [ ! -f "$AUTHOURS_DIR/blogs.yaml" ]; then
    cat > "$AUTHOURS_DIR/blogs.yaml" << 'EOF'
categories:
  1: "Sports"
  2: "Cinema"
  3: "Technology"
  4: "Travel"
  5: "Food"
  6: "Lifestyle"
  7: "Finance"
blogs: []

EOF
    chown "$author_name:$author_name" "$AUTHOURS_DIR/blogs.yaml"
fi

publish_article() {
    filename="$1"

    if [ ! -f "${BLOGS_DIR}/${filename}" ]; then
        echo "Error: Article ${filename} does not exist in your blogs directory."
        exit 1
    fi

    already_published=$(yq e ".blogs[] | select(.file_name == \"$filename\" and .publish_status == true)" "$AUTHOURS_DIR/blogs.yaml")
    if [ -n "$already_published" ]; then
        echo "Error: $filename is already published."
        exit 1
    fi

    yq e -o=props '.categories' "$AUTHOURS_DIR/blogs.yaml"

    echo -n "Enter preferred category order (comma-separated numbers, e.g., 2,1,3): "
    read -r category_order

    

    categories=($(echo "$category_order" | tr ',' ' '))
    for i in "${categories[@]}"; do
        if [ "$i" -lt 1 ] || [ "$i" -gt 7 ]; then
            echo "Error: Category ID '$i' must be between 1 and 7."
            exit 1
        fi
    done

    tmp_file="/tmp/${author_name}_blogs.yaml"
    yq eval ".blogs += [{
      \"file_name\": \"$filename\",
      \"publish_status\": true,
      \"cat_order\": [$category_order]
    }]" "$AUTHOURS_DIR/blogs.yaml" > "$tmp_file"
    rsync -a --inplace "$tmp_file" "$AUTHOURS_DIR/blogs.yaml"
    rm "$tmp_file"

    safe_filename=$(sanitize "$filename")
    safe_order=$(sanitize "$category_order")
    query="INSERT INTO \`${TABLE}\` (filename, publish_status, cat_order)
           VALUES ('${safe_filename}', 'TRUE', '${safe_order}')
           ON DUPLICATE KEY UPDATE publish_status='TRUE', cat_order='${safe_order}';"
    execute_sql_prepared "$query"

    ln -sf "${BLOGS_DIR}/${filename}" "${PUBLIC_DIR}/${filename}"
    echo "$filename is published"
}

archive_article() {
    filename="$1"

    

    if ! yq e ".blogs[] | select(.file_name == \"$filename\")" "$AUTHOURS_DIR/blogs.yaml" >/dev/null; then
        echo "Error: Article $filename not found in metadata"
        exit 1
    fi

    if [ ! -f "${BLOGS_DIR}/${filename}" ]; then
        echo "Error: Article ${filename} does not exist in your blogs directory."
        exit 1
    fi

    tmp_file="/tmp/${author_name}_blogs.yaml"
    yq e "(.blogs[] | select(.file_name == \"$filename\").publish_status) = false" "$AUTHOURS_DIR/blogs.yaml" > "$tmp_file"
    rsync -a --inplace "$tmp_file" "$AUTHOURS_DIR/blogs.yaml"
    rm "$tmp_file"

    safe_filename=$(sanitize "$filename")
    query="UPDATE \`${TABLE}\` SET publish_status='FALSE' WHERE filename='${safe_filename}';"
    execute_sql_prepared "$query"

    rm -f "${PUBLIC_DIR}/${filename}"
    echo "Archived $filename"
}

delete_article() {
    filename="$1"

    
    if ! yq e ".blogs[] | select(.file_name == \"$filename\")" "$AUTHOURS_DIR/blogs.yaml" >/dev/null; then
        echo "Error: Article $filename not found in metadata"
        exit 1
    fi

    if [ ! -f "${BLOGS_DIR}/${filename}" ]; then
        echo "Error: Article ${filename} does not exist in your blogs directory."
        exit 1
    fi

    DEL_LOG="$AUTHOURS_DIR/deletioncategory.log"
    [ -f "$DEL_LOG" ] || touch "$DEL_LOG"

    cat_order=$(yq e ".blogs[] | select(.file_name == \"$filename\").cat_order[]" "$AUTHOURS_DIR/blogs.yaml" | tr '\n' ' ')
    echo "$cat_order" >> "$DEL_LOG"

    tmp_file="/tmp/${author_name}_blogs.yaml"
    yq e "del(.blogs[] | select(.file_name == \"$filename\"))" "$AUTHOURS_DIR/blogs.yaml" > "$tmp_file"
    rsync -a --inplace "$tmp_file" "$AUTHOURS_DIR/blogs.yaml"
    rm "$tmp_file"

    safe_filename=$(sanitize "$filename")
    query="DELETE FROM \`${TABLE}\` WHERE filename='${safe_filename}';"
    execute_sql_prepared "$query"

    rm -f "${BLOGS_DIR}/${filename}"
    rm -f "${PUBLIC_DIR}/${filename}"

    echo "Deleted $filename completely"
}

edit_article() {
    filename="$1"


    if ! yq e ".blogs[] | select(.file_name == \"$filename\")" "$AUTHOURS_DIR/blogs.yaml" >/dev/null; then
        echo "Error: Article $filename not found in metadata"
        exit 1
    fi

    if [ ! -f "${BLOGS_DIR}/${filename}" ]; then
        echo "Error: Article ${filename} does not exist in your blogs directory."
        exit 1
    fi

    yq e -o=props '.categories' "$AUTHOURS_DIR/blogs.yaml"
    echo -n "Enter new category order (comma-separated numbers):(eg 2,1,3) "
    read -r new_order

    

    categories=($(echo "$new_order" | tr ',' ' '))
    for i in "${categories[@]}"; do
        if [ "$i" -lt 1 ] || [ "$i" -gt 7 ]; then
            echo "Error: Category ID '$i' must be between 1 and 7."
            exit 1
        fi
    done

    tmp_file="/tmp/${author_name}_blogs.yaml"
    yq e "(.blogs[] | select(.file_name == \"$filename\").cat_order) = [$new_order]" "$AUTHOURS_DIR/blogs.yaml" > "$tmp_file"
    rsync -a --inplace "$tmp_file" "$AUTHOURS_DIR/blogs.yaml"
    rm "$tmp_file"

    safe_filename=$(sanitize "$filename")
    safe_order=$(sanitize "$new_order")
    query="UPDATE \`${TABLE}\` SET cat_order='${safe_order}' WHERE filename='${safe_filename}';"
    execute_sql_prepared "$query"

    echo "Updated categories for $filename"
}

case "$1" in
    -p) publish_article "$2" ;;
    -a) archive_article "$2" ;;
    -d) delete_article "$2" ;;
    -e) edit_article "$2" ;;
    *)
        echo "Usage:  { -p | -a | -d | -e } <filename>"
        echo "Options:"
        echo "  -p <filename>    Publish an article"
        echo "  -a <filename>    Archive an article"
        echo "  -d <filename>    Delete an article"
        echo "  -e <filename>    Edit article categories"
        exit 1
        ;;
esac




