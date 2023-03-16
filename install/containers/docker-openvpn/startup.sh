#!/bin/sh

/usr/sbin/openvpn --status /run/openvpn/server.status 10 --cd /etc/openvpn --config /etc/openvpn/server.conf --writepid /run/openvpn/server.pid
