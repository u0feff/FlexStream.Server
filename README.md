# Proxy

```bash
adduser --system --no-create-home --group "tunnel-user"
ssh-keygen -t ed25519 -f /etc/tunnel/id_ed25519 -C "tunnel-user"
chown -R tunnel-user:tunnel-user /etc/tunnel/
```

# Network plan

```
IPv4 schema:
  10.node.server[3]network[3]host[2].host

+-+ 10.10.0.0/16                      #+-+ Aliases
| +-- 10.10.0.1                       #| +-- VPN gateway
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
  fd42:0:node:server::network:subnetwork:host

+-+ fd42:0:10:0::0:0:0/48               #+-+ Aliases
| +-- fd42:0:10:0::0:0:1                #| +-- VPN gateway
|                                       #|
+-+ fd42:0:i:0::0:0:0/48                #--+ VPN
  +-+ fd42:0:i:0::0:0:0/64              #  +-+ TCP server
  | +-+ fd42:0:i:0::0:0:0/96            #  | +-+ Public
  | | +-- fd42:0:i:0::0:0:1             #  | | +-- Gateway
  | | +-- fd42:0:i:0::0:1:0/112         #  | | +-- DHCP pool
  | |                                   #  | |
  | +-+ fd42:0:i:0::1:0:0/96            #  | +-+ Private
  |                                     #  |
  +-+ fd42:0:i:1::0:0:0/64              #  +-+ UDP server
  | +-+ fd42:0:i:1::0:0:0/96            #  | +-+ Public
  | | +-- fd42:0:i:1::0:0:1             #  | | +-- Gateway
  | | +-- fd42:0:i:1::0:1:0/112         #  | | +-- DHCP pool
  | |                                   #  | |
  | +-+ fd42:0:i:1::1:0:0/96            #  | +-+ Private
  |                                     #  |
  +-+ fd42:0:i:2::0:0:0/64              #  +-+ Ping server
    +-+ fd42:0:i:2::0:0:0/96            #    +-+ Public
      +-- fd42:0:i:2::0:0:1             #      +-- Gateway
      +-- fd42:0:i:2::0:1:0/112         #      +-- DHCP pool

Node id:
1..9 - reserved
10 - aliases
11..20 - internal
21..199 - public
200 - internal routes
```
