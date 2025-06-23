#!/bin/bash

if ! id -nG "$(whoami)" | grep -qw "g_mod"; then
    echo "Access denied: Only moderators (g_mod group) can run this script."
    exit 1
fi
MOD_HOME="/home/mods/$(whoami)"
BLACKLIST_FILE="$MOD_HOME/blacklist.txt"

make_blacklist() {
    if [ ! -f "$BLACKLIST_FILE" ]; then
        echo "Enter words to blacklist (separated by spaces):"
        read -a words
        printf "%s\n" "${words[@]}" > "$BLACKLIST_FILE"
        echo "Blacklist created at $BLACKLIST_FILE"
    fi
}

TEMP_VIOLATION_FILE="/tmp/violations_$$"
: > "$TEMP_VIOLATION_FILE"

checking_articles() {
    author_uname="$1"
    find "/home/authors/$author_uname/public" -type l | while read -r symlink; do
        article_name=$(basename "$symlink")
        article=$(readlink -f "$symlink")

        awk -v article_name="$article_name" -v author_uname="$author_uname" -v article="$article" -v TEMP_VIOLATION_FILE="$TEMP_VIOLATION_FILE" '
        BEGIN {
            blacklist_file = ENVIRON["BLACKLIST_FILE"]
            count = 0
            while ((getline word < blacklist_file) > 0) {
                blacklist[count++] = tolower(word)
            }
            close(blacklist_file)
            violations = 0
            temp_file = "/tmp/temp_processed"
        }
{
    line = $0
    line_lower = tolower($0)
    line_number = NR

    for (j = 0; j < count; j++) {
        word = blacklist[j]
        while ((match(line_lower, word)) > 0) {
            start = RSTART
            len = RLENGTH
            stars = ""
            for (k = 1; k <= len; k++) stars = stars "*"
            line = substr(line, 1, start - 1) stars substr(line, start + len)
            line_lower = tolower(line)
            violations++
            print "Found blacklisted word", word, "in", article_name, "at line", line_number
        }
    }

    print line >> temp_file
}
END {
    if (violations > 5) {
        print author_uname, article_name, violations >> TEMP_VIOLATION_FILE
        system("rm -f \"" temp_file "\"")
    } else if (violations > 0) {
        system("mv \"" temp_file "\" \"" article "\"")
    } else {
        system("rm -f \"" temp_file "\"")
    }
}
        ' "$article"
    done
}

export BLACKLIST_FILE
export USER=$(whoami)

if [ ! -f "$BLACKLIST_FILE" ]; then
    make_blacklist
fi

if [ -z "$1" ]; then
    echo "Usage: $0 <author_username>"
    exit 1
fi
author="$1"

managed_dir="$MOD_HOME/managed_authors/$author"

if [ ! -d "$managed_dir" ]; then
    echo "Error: You are not assigned to moderate author '$author'."
    exit 1
fi

checking_articles "$1"

if [ -s "$TEMP_VIOLATION_FILE" ]; then
    while read -r author_uname article_name violations; do
        echo "Blog $article_name is archived due to excessive blacklisted words."

        rm -f "/home/mods/$(whoami)/managed_authors/$author_uname/$article_name"
        rm -f "/home/authors/$author_uname/public/$article_name"

        yq eval "(.blogs[] | select(.file_name == \"$article_name\").publish_status) = false" \
            "/home/authors/$author_uname/blogs.yaml" > /tmp/tmp_yaml && \
        rsync -a --inplace /tmp/tmp_yaml "/home/authors/$author_uname/blogs.yaml" > /dev/null 2>&1 && \
        rm /tmp/tmp_yaml

        yq eval "(.blogs[] | select(.file_name == \"$article_name\").mod_comments) = \"found $violations blacklisted words\"" \
            "/home/authors/$author_uname/blogs.yaml" > /tmp/tmp_yaml && \
        rsync -a --inplace /tmp/tmp_yaml "/home/authors/$author_uname/blogs.yaml" > /dev/null 2>&1 && \
        rm /tmp/tmp_yaml

    done < "$TEMP_VIOLATION_FILE"
fi


rm -f "$TEMP_VIOLATION_FILE"
echo "process done"
