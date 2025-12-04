#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]:-$0}")"

source "$SCRIPT_DIR/tls-key.sh"

gen() {
    if [[ -f "$CERTS_DIR/ca.key" ]]; then
        echo "Certificates already generated" >&2
        return 1
    fi

    mkdir -p "$CERTS_DIR"

    trap 'rm -rf "$CERTS_DIR"' EXIT

    gen_tls_key

    # Generate CA private key (ECC P-256)
    openssl ecparam -genkey -name prime256v1 -out "$CERTS_DIR/ca.key"

    # Generate CA certificate
    openssl req -new -x509 -key "$CERTS_DIR/ca.key" -out "$CERTS_DIR/ca.crt" -days 3650 -config "$SCRIPT_DIR/vk-ca.conf" -extensions v3_ca

    # Generate server private key (ECC P-256)
    openssl ecparam -genkey -name prime256v1 -out "$CERTS_DIR/server.key"

    # Generate server certificate signing request
    openssl req -new -key "$CERTS_DIR/server.key" -out "$CERTS_DIR/server.csr" -config "$SCRIPT_DIR/vk-server.conf"

    # Generate server certificate signed by our CA
    openssl x509 -req -in "$CERTS_DIR/server.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial -out "$CERTS_DIR/server-raw.crt" -days 3650 -extensions v3_req -extfile "$SCRIPT_DIR/vk-server.conf"

    echo "Certificates generated. Mimicrying..."

    # Get original certificate
    echo | openssl s_client -showcerts -servername stats.vk-portal.net -connect stats.vk-portal.net:443 2>/dev/null | openssl x509 -inform pem -out "$CERTS_DIR/original.crt"

    # Extract SCT extension in DER format
    openssl x509 -in "$CERTS_DIR/original.crt" -outform DER -out "$CERTS_DIR/original.der"

    CERTS_DIR="$CERTS_DIR" python3 "$SCRIPT_DIR/add_sct.py"

    rm "$CERTS_DIR/server.csr" "$CERTS_DIR/original.crt" "$CERTS_DIR/original.der"

    trap - EXIT
}

debug_show() {
    echo -e "\n=== Certificate Details ==="
    openssl x509 -in "$CERTS_DIR/server.crt" -text -noout

    echo -e "\n=== Certificate Verification ==="
    openssl verify -CAfile "$CERTS_DIR/ca.crt" "$CERTS_DIR/server-raw.crt"

    echo -e "\n=== Certificate with SCT Verification ==="
    openssl verify -CAfile "$CERTS_DIR/ca.crt" "$CERTS_DIR/server.crt"
}

create_client() {
    local name=$1

    if [[ -f "$CERTS_DIR/clients/$name.crt" ]]; then
        echo "Specified client CN already exists" >&2
        return 1
    fi

    mkdir -p "$CERTS_DIR/clients"

    openssl ecparam -genkey -name prime256v1 -out "$CERTS_DIR/clients/$name.key"
    openssl req -new -key "$CERTS_DIR/clients/$name.key" -out "$CERTS_DIR/clients/$name.csr" -subj "/CN=$name"
    openssl x509 -req -in "$CERTS_DIR/clients/$name.csr" -CA "$CERTS_DIR/ca.crt" -CAkey "$CERTS_DIR/ca.key" -CAcreateserial -out "$CERTS_DIR/clients/$name.crt" -days 365 -extfile "$SCRIPT_DIR/vk-client.conf"

    rm "$CERTS_DIR/clients/$name.csr"
}

ensure_client_exists() {
    local name=$1

    if [[ ! -f "$CERTS_DIR/clients/$name.crt" ]]; then
        echo "Specified client CN not exists" >&2
        return 1
    fi
}

show_client_ovpn() {
    local name=$1

    mkdir -p "$CERTS_DIR/clients"

    ensure_client_exists $name

    cat "$SCRIPT_DIR/client-template.txt"

    local server_cn="$(openssl x509 -in "$CERTS_DIR/server.crt" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject=//; s/.*CN=\([^,\/]*\).*/\1/p')"
    echo "verify-x509-name $server_cn name"

    echo "<ca>"
    cat "$CERTS_DIR/ca.crt"
    echo "</ca>"

    echo "<cert>"
    awk '/BEGIN/,/END CERTIFICATE/' "$CERTS_DIR/clients/$name.crt"
    echo "</cert>"

    echo "<key>"
    cat "$CERTS_DIR/clients/$name.key"
    echo "</key>"

    echo "<tls-crypt>"
    cat "$CONFIG_DIR/openvpn/certs/tls-crypt.key"
    echo "</tls-crypt>"
}

list_clients() {
    mkdir -p "$CERTS_DIR/clients"

    find "$CERTS_DIR/clients" -maxdepth 1 -type f -name '*.crt' -exec basename {} .crt \;
}

usage() {
    cat <<EOF
Usage: $0 <command> [args...]

Commands:
  gen                        Generate CA + server certs
  debug-show                 Debug show certificate
  create-client <name>       Create a client certificate (nopass)
  show-client-ovpn <name>    Print client ovpn to stdout
  list-clients               List existing (valid) client CNs
  help                       Show this help

Examples:
  $0 gen
  $0 create-client alice
  $0 show-client-ovpn alice > alice.ovpn
  $0 list-clients
EOF
}

CONFIG_DIR="${CONFIG_DIR:-/var/lib/flexstream/server}"

mkdir -p "$CONFIG_DIR"

CERTS_DIR="$CONFIG_DIR/openvpn/certs/vk"

mkdir -p "$CERTS_DIR"

if [[ $# -lt 1 ]]; then
    usage
    exit 1
fi

cmd="$1"; shift

case "$cmd" in
    "gen")
        gen
        ;;
    "debug-show")
        debug_show
        ;;
    "create-client")
        if [[ $# -ne 1 ]]; then
            echo "create-client requires a client name" >&2
            exit 1
        fi
        create_client "$1"
        ;;
    "show-client-ovpn")
        if [[ $# -ne 1 ]]; then
            echo "show-client-ovpn requires a client name" >&2
            exit 1
        fi
        show_client_ovpn "$1"
        ;;
    "list-clients")
        list_clients
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