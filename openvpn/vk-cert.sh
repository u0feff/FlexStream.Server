#!/bin/bash
set -euo pipefail

source tls.sh

gen() {
    if [[ -d "certs/vk" ]]; then
        echo "Certificates already generated" >&2
        return 1
    fi

    mkdir -p certs/vk

    gen_tls_key

    # Generate CA private key (ECC P-256)
    openssl ecparam -genkey -name prime256v1 -out certs/vk/ca.key

    # Generate CA certificate
    openssl req -new -x509 -key certs/vk/ca.key -out certs/vk/ca.crt -days 3650 -config vk-ca.conf -extensions v3_ca

    # Generate server private key (ECC P-256)
    openssl ecparam -genkey -name prime256v1 -out certs/vk/server.key

    # Generate server certificate signing request
    openssl req -new -key certs/vk/server.key -out certs/vk/server.csr -config vk-server.conf

    # Generate server certificate signed by our CA
    openssl x509 -req -in certs/vk/server.csr -CA certs/vk/ca.crt -CAkey certs/vk/ca.key -CAcreateserial -out certs/vk/server-raw.crt -days 3650 -extensions v3_req -extfile vk-server.conf

    echo "Certificates generated. Mimicrying..."

    # Get original certificate
    echo | openssl s_client -showcerts -servername stats.vk-portal.net -connect stats.vk-portal.net:443 2>/dev/null | openssl x509 -inform pem -out certs/vk/original.crt

    # Extract SCT extension in DER format
    openssl x509 -in certs/vk/original.crt -outform DER -out certs/vk/original.der

    python3 add_sct.py

    rm certs/vk/server.csr certs/vk/original.crt certs/vk/original.der
}

debug_show() {
    echo -e "\n=== Certificate Details ==="
    openssl x509 -in certs/vk/server.crt -text -noout

    echo -e "\n=== Certificate Verification ==="
    openssl verify -CAfile certs/vk/ca.crt certs/vk/server-raw.crt

    echo -e "\n=== Certificate with SCT Verification ==="
    openssl verify -CAfile certs/vk/ca.crt certs/vk/server.crt
}

create_client() {
    local name=$1

    if [[ -f "certs/vk/clients/$name.crt" ]]; then
        echo "Specified client CN already exists" >&2
        return 1
    fi

    mkdir -p certs/vk/clients

    openssl ecparam -genkey -name prime256v1 -out certs/vk/clients/$name.key
    openssl req -new -key certs/vk/clients/$name.key -out certs/vk/clients/$name.csr -subj "/CN=$name"
    openssl x509 -req -in certs/vk/clients/$name.csr -CA certs/vk/ca.crt -CAkey certs/vk/ca.key -CAcreateserial -out certs/vk/clients/$name.crt -days 365 -extfile vk-client.conf

    rm certs/vk/clients/$name.csr
}

ensure_client_exists() {
    local name=$1

    if [[ ! -f "certs/vk/clients/$name.crt" ]]; then
        echo "Specified client CN not exists" >&2
        return 1
    fi
}

show_client_ovpn() {
    local name=$1

    ensure_client_exists $name

    cat client-template.txt

    local server_cn="$(openssl x509 -in "certs/vk/server.crt" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject=//; s/.*CN=\([^,\/]*\).*/\1/p')"
    echo "verify-x509-name $server_cn name"

    echo "<ca>"
    cat "certs/vk/ca.crt"
    echo "</ca>"

    echo "<cert>"
    awk '/BEGIN/,/END CERTIFICATE/' "certs/vk/clients/$name.crt"
    echo "</cert>"

    echo "<key>"
    cat "certs/vk/clients/$name.key"
    echo "</key>"

    echo "<tls-crypt>"
    cat "certs/tls-crypt.key"
    echo "</tls-crypt>"
}

list_clients() {
    ls certs/vk/clients/*.crt | xargs -n1 basename -s .crt
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
  $0 revoke alice
EOF
}

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