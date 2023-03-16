#!/bin/bash
#bdereims@vmware.com

. ./env

DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts

main() {
	echo "=== List of cPods."
	cat /etc/hosts | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print $1," ",toupper($2),"("$3")"}' | sort
}

main $1
