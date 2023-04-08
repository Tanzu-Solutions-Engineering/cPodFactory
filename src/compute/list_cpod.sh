#!/bin/bash
#bdereims@vmware.com

. ./src/env

DNSMASQ=/etc/dnsmasq.conf

cat ${DNSMASQ} | grep cpod | cut -f 2 -d '/' | sed "s/\..*$//"
