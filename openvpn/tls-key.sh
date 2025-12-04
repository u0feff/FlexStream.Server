#!/bin/bash

gen_tls_key() {
    if [[ -f "$CONFIG_DIR/openvpn/certs/tls-crypt.key" ]]; then
        return 0
    fi
    
    openvpn --genkey --secret "$CONFIG_DIR/openvpn/certs/tls-crypt.key"
}