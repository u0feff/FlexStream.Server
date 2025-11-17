#!/bin/bash
set -euo pipefail

list_file="dump_list.txt"
archive="config.tar.gz"

temp_dir=$(mktemp -d)
trap 'rm -rf "$temp_dir"' EXIT

while IFS='|' read -r src dst; do
    temp_dst="$temp_dir/$dst"
    mkdir -p "$(dirname "$temp_dst")"

    if [[ -d "$src" ]]; then
        while IFS= read -r -d '' current_src; do
            current_rel="$(realpath -s --relative-to="$src" "$current_src")"
            current_dst="$temp_dst/$current_rel"
            mkdir -p "$(dirname "$current_dst")"
            ln -s "$(realpath -s "$current_src")" "$current_dst"
        done < <(find "$src" -mindepth 1 \( -type f -o -type l \) -print0)

        while IFS= read -r -d '' current_src; do
            current_rel="$(realpath -s --relative-to="$src" "$current_src")"
            mkdir -p "$temp_dst/$current_rel"
        done < <(find "$src" -type d -empty -print0)
    elif [[ -e "$src" ]]; then
        ln -s "$(realpath -s "$src")" "$temp_dst"
    else
        echo "Source not found: $src -> $dst" >&2
        exit 1
    fi
done < <(awk '
  # strip BOM and trailing CR (just in case)
  NR==1 { sub(/^\xef\xbb\xbf/,"") }
  { sub(/\r$/,"") }

  # skip empty/comment lines (after trimming leading space)
  { tmp=$0; gsub(/^[[:space:]]+/,"",tmp) }
  tmp ~ /^(#|$)/ { next }

  {
    p = index($0, "|"); if (!p) next
    src = substr($0, 1, p-1)
    dst = substr($0, p+1)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", src)
    gsub(/^[[:space:]]+|[[:space:]]+$/, "", dst)
    if (src=="" || dst=="") next
    print src "|" dst
  }
' $list_file)

tar -C "$temp_dir" -h -czf "$archive" .
