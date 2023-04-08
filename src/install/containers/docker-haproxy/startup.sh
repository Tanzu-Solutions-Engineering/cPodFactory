#!/bin/sh

#/usr/sbin/apache2ctl start
/usr/sbin/haproxy -d -f /etc/haproxy/haproxy.cfg -p /var/run/haproxy.pid
