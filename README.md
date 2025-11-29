# Dump tree

```
.
├── config.sh
├── 3proxy
│   └── auth.txt
├── openvpn
│   └── certs
│       ├── tls-crypt.key
│       ├── main
│       │   ├── ca.crt
│       │   ├── crl.pem
│       │   ├── server.crt
│       │   └── server.key
│       └── vk
│           ├── ca.crt
│           ├── server.crt
│           └── server.key
└── stunnel
    └── certs
        ├── server.crt
        ├── server.key
        └── clients
            ├── ca/*.crt
            └── crl/*.crt
```

# OpenVPN network

```
host:
1..9 - reserved
10 - aliases
11..20 - internal
21..199 - public

IPv4 schema:
  10.host.server[3]network[3]host[2].host

+-+ 10.10.0.0/16                      #+-+ VPN alias
| +-- 10.10.0.1                       #| +-- Gateway
|                                     #|
+-+ 10.i.0.0/16                       #+-+ VPN
  +-+ 10.i.0.0/19                     #  +-+ TCP server
  | +-+ 10.i.0.0/22                   #  | +-+ Public
  | | +-- 10.i.0.1                    #  | | +-- Gateway
  | | +-- 10.i.0.100 - 10.i.0.200     #  | | +-- DHCP pool
  | |                                 #  | |
  | +-+ 10.i.4.0/22                   #  | +-+ Private
  |                                   #  |
  +-+ 10.i.32.0/19                    #  +-+ UDP server
  | +-+ 10.i.32.0/22                  #  | +-+ Public
  | | +-- 10.i.32.1                   #  | | +-- Gateway
  | | +-- 10.i.32.100 - 10.i.32.200   #  | | +-- DHCP pool
  | |                                 #  | |
  | +-+ 10.i.36.0/22                  #  | +-+ Private
  |                                   #  |
  +-+ 10.i.64.0/19                    #  +-+ Ping server
    +-+ 10.i.64.0/22                  #    +-+ Public
      +-- 10.i.64.1                   #      +-- Gateway
      +-- 10.i.64.100 - 10.i.64.200   #      +-- DHCP pool

IPv6 schema:
  fd42:host:server::network:subnetwork:host

+-+ fd42:10:0::0:0:0/48               #+-+ VPN alias
| +-- fd42:10:0::0:0:1                #| +-- Gateway
|                                     #|
+-+ fd42:i:0::0:0:0/48                #--+ VPN
  +-+ fd42:i:0::0:0:0/64              #  +-+ TCP server
  | +-+ fd42:i:0::0:0:0/96            #  | +-+ Public
  | | +-- fd42:i:0::0:0:1             #  | | +-- Gateway
  | | +-- fd42:i:0::0:1:0/112         #  | | +-- DHCP pool
  | |                                 #  | |
  | +-+ fd42:i:0::1:0:0/96            #  | +-+ Private
  |                                   #  |
  +-+ fd42:i:1::0:0:0/64              #  +-+ UDP server
  | +-+ fd42:i:1::0:0:0/96            #  | +-+ Public
  | | +-- fd42:i:1::0:0:1             #  | | +-- Gateway
  | | +-- fd42:i:1::0:1:0/112         #  | | +-- DHCP pool
  | |                                 #  | |
  | +-+ fd42:i:1::1:0:0/96            #  | +-+ Private
  |                                   #  |
  +-+ fd42:i:2::0:0:0/64              #  +-+ Ping server
    +-+ fd42:i:2::0:0:0/96            #    +-+ Public
      +-- fd42:i:2::0:0:1             #      +-- Gateway
      +-- fd42:i:2::0:1:0/112         #      +-- DHCP pool
```
