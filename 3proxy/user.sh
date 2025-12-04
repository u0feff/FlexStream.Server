#!/bin/bash
set -euo pipefail

user_exists(){
    local name="$1"
    awk -F: -v name="$name" '
        $1==name { print 1; found=1; exit }
        END { if (!found) print 0 }
    ' "$ACCOUNTS_FILE"
}

ensure_user_exists() {
    local name=$1

    local exists=$(user_exists "$name")
    if [[ $exists == '0' ]]; then
        echo "Specified user name not exists" >&2
        return 1
    fi
}

add_user() {
    local name="$1"
    local password="$2"

    if [[ -z "$name" || "$name" == *:* ]]; then
        echo "Invalid user name: must be non-empty and must not contain ':'" >&2
        return 1
    fi

    local exists=$(user_exists "$name")
    if [[ $exists == '1' ]]; then
        echo "Specified user name already exists" >&2
        return 1
    fi

    local password_hash="$(openssl passwd -1 -- \"$password\")"

    printf '%s\n' "$name:CR:$password_hash" >> "$ACCOUNTS_FILE"
}

list_users() {
    awk -F: '
        $1 != "" { print $1 }
    ' "$ACCOUNTS_FILE"
}

remove_user() {
    local name="$1"

    ensure_user_exists "$name"

    local tmp=$(mktemp)

    trap 'rm -f "$tmp"' EXIT

    awk -F: -v name="$name" '
        $1 != name { print }
    ' "$ACCOUNTS_FILE" > "$tmp"

    mv "$tmp" "$ACCOUNTS_FILE"

    trap - EXIT
}

usage() {
    cat <<EOF
Usage: $0 <command> [args...]

Commands:
  dry-run                    Initialize PKI and generate CA + server certs
  add <name>                 Adds user
  list                       List existing users
  remove <name>              Removes user
  help                       Show this help

Examples:
  $0 dry-run
  $0 add-user alice
  $0 list-clients
  $0 remove-user alice
EOF
}

CONFIG_DIR="${CONFIG_DIR:-/var/lib/flexstream/server}"

mkdir -p "$CONFIG_DIR"

ACCOUNTS_FILE="$CONFIG_DIR/3proxy/accounts.txt"

mkdir -p "$(dirname "$ACCOUNTS_FILE")"
touch "$ACCOUNTS_FILE"

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

cmd="$1"; shift

case "$cmd" in
    "dry-run")
        ;;
    "add")
        if [[ $# -ne 2 ]]; then
            echo "add-user requires a user name and password" >&2
            exit 1
        fi
        add_user "$1" "$2"
        ;;
    "list")
        list_users
        ;;
    "remove")
        if [[ $# -ne 1 ]]; then
            echo "remove-user requires a user name" >&2
            exit 1
        fi
        remove_user "$1"
        ;;
    help|--help|-h)
        usage
        ;;
    *)
        echo "Unknown command: $cmd" >&2
        usage
        exit 2
        ;;
esac