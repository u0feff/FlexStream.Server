#!/bin/bash

gen_tls_key() {
    if [[ ! -f certs/tls-crypt.key ]]; then
        openvpn --genkey --secret certs/tls-crypt.key
    fi
}