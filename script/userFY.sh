#!/bin/bash

if ! id -nG | grep -qw "g_admin"; then
    echo "Current user should be an admin"
    exit 1
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <user_prefs_file>"
    exit 1
fi

user_prefs_file=$1
users_base_dir="/home/users"
authors_base_dir="/home/authors"

declare -A category_names=(
    [1]="Sports"
    [2]="Cinema"
    [3]="Technology"
    [4]="Travel"
    [5]="Food"
    [6]="Lifestyle"
    [7]="Finance"
)

declare -A blog_assignments


while IFS= read -r -d $'\0' blog_file; do
    author=$(basename "$(dirname "$blog_file")")
    blog_count=$(yq e '.blogs | length' "$blog_file")

    for ((i = 0; i < blog_count; i++)); do
        if [ "$(yq e ".blogs[$i].publish_status" "$blog_file")" == "true" ]; then
            blog_name=$(yq e ".blogs[$i].file_name" "$blog_file")
            blog_key="$author|$blog_name"

            mapfile -t categories < <(yq e ".blogs[$i].cat_order[]" "$blog_file")
            for cat_id in "${categories[@]}"; do
                cat_name="${category_names[$cat_id]}"
                eval "category_blogs_$cat_name+=(\"$blog_key\")"
            done

            blog_assignments["$blog_key"]=0
        fi
    done

done < <(find "$authors_base_dir" -name blogs.yaml -print0)

user_count=$(yq e '.users | length' "$user_prefs_file")

for ((i = 0; i < user_count; i++)); do
    username=$(yq e ".users[$i].username" "$user_prefs_file")
    FYI_PATH="$users_base_dir/$username/FYI.yaml"
    echo "ForYouPage: []" > "$FYI_PATH"
    chmod 644 "$FYI_PATH"

    pref1=$(yq e ".users[$i].pref1" "$user_prefs_file")
    pref2=$(yq e ".users[$i].pref2" "$user_prefs_file")
    pref3=$(yq e ".users[$i].pref3" "$user_prefs_file")
    user_prefs=("$pref1" "$pref2" "$pref3")

    for pref in "${user_prefs[@]}"; do
      

        eval "blogs=(\"\${category_blogs_$pref[@]}\")"
        least_blog=""
        least_count=999999

        for blog in "${blogs[@]}"; do
            [ -z "$blog" ] && continue

            if yq e ".ForYouPage[]" "$FYI_PATH" 2>/dev/null | grep -Fxq "$blog"; then
                continue
            fi

            count=${blog_assignments["$blog"]}
            if (( count < least_count )); then
                least_count=$count
                least_blog="$blog"
            fi
        done

        if [ -n "$least_blog" ]; then
            tmp_file="/tmp/${username}_FYI.yaml"
            yq eval ".ForYouPage += [\"$least_blog\"]" "$FYI_PATH" > "$tmp_file"
            rsync -a --inplace "$tmp_file" "$FYI_PATH"
            rm -f "$tmp_file"

            blog_assignments["$least_blog"]=$((least_count + 1))
            
        fi
    done

done

echo "FYI blog recommendation completed."





