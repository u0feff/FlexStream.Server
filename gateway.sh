#!/bin/bash
set -euo pipefail

validate_ipv4() {
    local ip="$1"

    if [ -z "${ip:-}" ]; then
        echo "IPv4 not set"
        return 1
    fi

    if [[ ! "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
        echo "Invalid IPv4: $ip"
        return 1
    else
        IFS='.' read -r a b c d <<<"$ip"

        for o in "$a" "$b" "$c" "$d"; do
            (( o >=0 && o <=255 )) || \
                { echo "IPv4 octet out of range: $ip"; return 1; }
        done
    fi
}

validate_ipv6() {
    local ip="$1"
    
    if [ -z "${ip:-}" ]; then
        echo "IPv6 not set"
        return 1
    fi

    if [[ ! "$ip" =~ ^[0-9A-Fa-f:]+$ ]]; then
        echo "Invalid IPv6: $ip"
        return 1
    fi

    if command -v python3 >/dev/null 2>&1; then
        python3 - <<EOF >/dev/null 2>&1 || { echo "Invalid IPv6: $ip"; return 1; }
import ipaddress
ipaddress.IPv6Address("$ip")
EOF
    fi
}

validate_node_id() {
    local id="$1"

    if ! [[ "$id" =~ ^[0-9]+$ ]] || (( id < 20 || id > 199 )); then
        echo "Node id must be in range 20..199" >&2
        return 1
    fi
}

find_free_port() {
    local port
    local used_ports=()

    for env_file in "$NODES_DIR"/*/env; do
        local p="$(grep '^RESPONSE_PORT=' "$env_file" | cut -d= -f2- | tr -d "'")"

        used_ports+=("$p")
    done

    for port in $(seq 8800 8900); do
        local in_use=0

        for used in "${used_ports[@]:-}"; do
            if [[ "$port" == "$used" ]]; then
                in_use=1
                break
            fi
        done

        if [[ $in_use == 0 ]]; then
            echo "$port"
            return 0
        fi
    done

    echo "No free ports available in range 8800.. 8900" >&2
    return 1
}

node_exists(){
    local id="$1"

    if [ -d "$NODES_DIR/$id" ]; then
        echo "1"
    else
        echo "0"
    fi
}

ensure_node_exists() {
    local id="$1"

    local exists=$(node_exists "$id")
    if [[ $exists == '0' ]]; then
        echo "Specified node id not exists" >&2
        return 1
    fi
}

add() {
    local id="$1"
    local ipv4="$2"
    local ipv6="$3"

    validate_node_id "$id"
    validate_ipv4 "$ipv4"
    validate_ipv6 "$ipv6"

    local exists=$(node_exists "$name")
    if [[ $exists == '1' ]]; then
        echo "Specified node id already exists" >&2
        return 1
    fi

    mkdir -p "$NODES_DIR/$id"

    local response_port=$(find_free_port)

    local env_file="$NODES_DIR/$id/env"

    printf "IPV4$=%q\n" "$ipv4" > "$env_file"
    printf "IPV6$=%q\n" "$ipv6" >> "$env_file"
    printf "RESPONSE_PORT=%q\n" "$response_port" >> "$env_file"
}

list() {
    local dirs=("$NODES_DIR"/*)

    if [ ! -e "${dirs[0]}" ]; then
        return 0
    fi

    printf "%-10s %-15s %-40s %s\n" "NODE_ID" "IPV4" "IPV6" "RESPONSE_PORT"
    printf '%80s\n' '' | tr ' ' '-'

    for node_dir in "$NODES_DIR"/*/; do
        local env_file="$node_dir/env"

        local node_id="$(basename "$node_dir")"
        local ipv4="$(grep '^IPV4=' "$env_file" | cut -d= -f2- | tr -d "'")"
        local ipv6="$(grep '^IPV6=' "$env_file" | cut -d= -f2- | tr -d "'")"
        local response_port="$(grep '^RESPONSE_PORT=' "$env_file" | cut -d= -f2- | tr -d "'")"

        printf "%-10s %-15s %-40s %s\n" "$node_id" "$ipv4" "$ipv6" "$response_port"
    done
}

make_config() {
    local id="$1"

    validate_node_id "$id"

    local temp_dir=$(mktemp -d)

    trap 'rm -rf "$temp_dir"' EXIT

    mkdir -p "$CONFIG_DIR/3proxy"
    cp -af "$CONFIG_DIR/3proxy/accounts.txt" "$temp_dir/3proxy/accounts.txt"

    mkdir -p "$CONFIG_DIR/dnsmasq"
    cp -af "$CONFIG_DIR/dnsmasq/env" "$temp_dir/dnsmasq/env"

    mkdir -p "$temp_dir/openvpn/certs/main" "$temp_dir/openvpn/certs/vk"
    cp -af \
        "$CONFIG_DIR/openvpn/certs/"{tls-crypt.key,main/ca.crt,main/crl.pem,main/server.crt,main/server.key,vk/ca.crt,vk/server.crt,vk/server.key} \
        "$temp_dir/openvpn/certs/"

    mkdir -p "$CONFIG_DIR/stunnel/certs"
    cp -raf "$CONFIG_DIR/stunnel/certs"{server.crt,server.key,clients/ca,clients/crl} "$temp_dir/stunnel/certs"

    mkdir -p "$CONFIG_DIR/tiny-tunnel"
    cp -af "$CONFIG_DIR/tiny-tunnel/env" "$temp_dir/tiny-tunnel/env"

    mkdir -p "$CONFIG_DIR/udp-forward"
    cp -af "$CONFIG_DIR/udp-forward/env" "$temp_dir/udp-forward/env"
}

CONFIG_DIR="${CONFIG_DIR:-/var/lib/flexstream/server}"

mkdir -p "$CONFIG_DIR"

NODES_DIR="$CONFIG_DIR/nodes"

mkdir -p "$NODES_DIR"

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

cmd="$1"; shift

case "$cmd" in
    "dry-run")
        ;;
    "add")
        if [[ $# -ne 3 ]]; then
            echo "add requires node id, ipv4, ipv6" >&2
            exit 1
        fi
        add "$1" "$2" "$3"
        ;;
    "list")
        list
        ;;
    "make-config")
        if [[ $# -ne 1 ]]; then
            echo "make-config requires node id" >&2
            exit 1
        fi
        make_config "$1"
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