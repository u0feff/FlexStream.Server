#!/bin/bash
set -euo pipefail

source tls.sh

ensure_easyrsa_installed() {
    if [[ ! -d easy-rsa/ ]]; then
        local version="3.1.2"

        echo "Downloading easy-rsa"

        wget -O easy-rsa.tgz https://github.com/OpenVPN/easy-rsa/releases/download/v${version}/EasyRSA-${version}.tgz
        mkdir -p easy-rsa
        tar xzf easy-rsa.tgz --strip-components=1 --no-same-owner --directory easy-rsa
        rm -f easy-rsa.tgz
    fi
}

easyrsa() {
    ensure_easyrsa_installed

    if [[ -d certs/main/pki ]]; then
        rm -f certs/main/pki/vars
        ln -s ../../../easy-rsa-vars certs/main/pki/vars
    fi

    EASYRSA_PKI=certs/main/pki easy-rsa/easyrsa "$@"
}

gen() {
    if [[ -d "certs/main" ]]; then
        echo "Certificates already generated" >&2
        return 1
    fi

    mkdir -p certs/main

    gen_tls_key

    easyrsa init-pki

    local server_cn="cn_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"
    local server_name="server_$(head /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 16 | head -n 1)"

    EASYRSA_CA_EXPIRE=3650 easyrsa --batch --req-cn="$server_cn" build-ca nopass
    EASYRSA_CERT_EXPIRE=3650 easyrsa --batch build-server-full "$server_name" nopass
    EASYRSA_CRL_DAYS=3650 easyrsa gen-crl

    ln -s pki/ca.crt certs/main/ca.crt 
    ln -s pki/private/ca.key certs/main/ca.key
    ln -s pki/crl.pem certs/main/crl.pem
    ln -s pki/issued/$server_name.crt certs/main/server.crt
    ln -s pki/private/$server_name.key certs/main/server.key
}


create_client() {
    local name=$1

    exists=$(tail -n +2 certs/main/pki/index.txt | grep -c -E "/CN=$name\$" || true)
    if [[ $exists == '1' ]]; then
        echo "Specified client CN already exists" >&2
        return 1
    fi

    EASYRSA_CERT_EXPIRE=3650 easyrsa --batch build-client-full "$name" nopass
}

ensure_client_exists() {
    local name=$1

    exists=$(tail -n +2 certs/main/pki/index.txt | grep "^V" | grep -c -E "/CN=$name\$" || true)
    if [[ $exists == '0' ]]; then
        echo "Specified client CN not exists" >&2
        return 1
    fi
}

show_client_ovpn() {
    local name=$1

    ensure_client_exists $name

    cat client-template.txt

    local server_cn="$(openssl x509 -in "certs/main/server.crt" -noout -subject -nameopt RFC2253 2>/dev/null | sed -n 's/^subject=//; s/.*CN=\([^,\/]*\).*/\1/p')"
    echo "verify-x509-name $server_cn name"

    echo "<ca>"
    cat "certs/main/ca.crt"
    echo "</ca>"

    echo "<cert>"
    awk '/BEGIN/,/END CERTIFICATE/' "certs/main/pki/issued/$name.crt"
    echo "</cert>"

    echo "<key>"
    cat "certs/main/pki/private/$name.key"
    echo "</key>"

    echo "<tls-crypt>"
    cat "certs/tls-crypt.key"
    echo "</tls-crypt>"
}

list_clients() {
    tail -n +2 certs/main/pki/index.txt | grep "^V" | cut -d '=' -f 2
}

revoke_client() {
    local name=$1

    ensure_client_exists $name

    easyrsa --batch revoke "$name"
    EASYRSA_CRL_DAYS=3650 easyrsa gen-crl
}

usage() {
    cat <<EOF
Usage: $0 <command> [args...]

Commands:
  gen                        Initialize PKI and generate CA + server certs
  create-client <name>       Create a client certificate (nopass)
  show-client-ovpn <name>    Print client ovpn to stdout
  list-clients               List existing (valid) client CNs
  revoke-client <name>       Revoke a client and regenerate CRL
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
    "revoke-client")
        if [[ $# -ne 1 ]]; then
            echo "revoke-client requires a client name" >&2
            exit 1
        fi
        revoke_client "$1"
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