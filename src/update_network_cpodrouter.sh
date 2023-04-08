#!/bin/bash

sed -i "s/router bgp 65201/router bgp ${1}/" /etc/quagga/bgpd.conf
systemctl restart bgpd
