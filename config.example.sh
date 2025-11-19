#!/bin/bash

export DNS='1.1.1.1#53'
export DNS6='2606:4700:4700::1111#53'
export DNS_IP4_ONLY='1.1.1.1#53'
export DNS_IP6_ONLY='2606:4700:4700::1111#53'

export EMAIL='admin@example.com'

export TUNNEL_PASSWORD='mysecretkey'
export TUNNEL_RESPONSE_SERVER='127.0.0.1:9000'

if [ -z "$INTERFACE" ]; then
    INTERFACE=$(ip route | sed -n 's/^default.*dev \([^\ ]*\).*/\1/p')

    if [ -z "$INTERFACE" ]; then
        INTERFACE=$(ip -6 route | sed -n 's/^default.*dev \([^\ ]*\).*/\1/p')
    fi
fi
