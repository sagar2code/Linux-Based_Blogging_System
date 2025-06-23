#!/bin/bash

if ! id -nG "$USER" | grep -qw "g_admin"; then
    echo "Access denied. Admins only."
    exit 1
fi


declare -A category_map=(
    [1]="Sports"
    [2]="Cinema"
    [3]="Technology"
    [4]="Travel"
    [5]="Food"
    [6]="Lifestyle"
    [7]="Finance"
)

REPORT="/home/admins/$USER/blog_report_$(date +%Y%m%d).txt"
echo "Blog Report - $(date)" > "$REPORT"
echo "----------------------------------" >> "$REPORT"

declare -A published_counts deleted_counts read_counts

for author_dir in /home/authors/*; do
    [ -d "$author_dir" ] || continue
    yaml_file="$author_dir/blogs.yaml"

 if [ -f "$yaml_file" ]; then
    blog_count=$(yq e '.blogs | length' "$yaml_file")
     for ((i=0; i<blog_count; i++)); do
        status=$(yq e ".blogs[$i].publish_status" "$yaml_file")
        if [ "$status" = "true" ]; then
            mapfile -t cids < <(yq e ".blogs[$i].cat_order[]" "$yaml_file")
            for cid in "${cids[@]}"; do
                ((published_counts[$cid]++))
            done
          fi
 done
fi

del_log="$author_dir/deletioncategory.log"
 if [ -f "$del_log" ]; then
         while read -r line; do
              for cid in $line; do
                [ -n "$cid" ] && ((deleted_counts[$cid]++))
            done
        done < "$del_log"
    fi
done


echo "Published Articles by Category:" >> "$REPORT"
for cid in "${!published_counts[@]}"; do
   
    clean_cid=$(echo "$cid" | xargs)  
    category="${category_map[$clean_cid]}"
    echo "$category: ${published_counts[$cid]}" >> "$REPORT"
done


echo "Deleted Articles by Category:" >> "$REPORT"
for cid in "${!deleted_counts[@]}"; do
    category="${category_map[$cid]}"
    echo "$category: ${deleted_counts[$cid]}" >> "$REPORT"
done

read_log="/var/log/blog_reads.log"
if [ -f "$read_log" ]; then
    while read -r file; do
        ((read_counts["$file"]++))
    done < "$read_log"

    echo -e "\nTop 3 Most Read Articles:" >> "$REPORT"
    for file in "${!read_counts[@]}"; do
        echo "${read_counts[$file]} $file"
    done | sort -rn | head -3 >> "$REPORT"
else
    echo "No read logs found." >> "$REPORT"
fi

echo "Report saved to $REPORT"


#cron job = 14 15 * 2,5,8,11 * bash -c '[ "$(date +\\%u)" -eq 4 ] || { d=$(date +\\%d); [ "$d" -le 7 -o "$d" -ge 25 ] && [ "$(date +\\%u)" -eq 6 ]; }'

