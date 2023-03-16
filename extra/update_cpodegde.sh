#!/bin/bash -e
#bdereims@vmware.com

backup_file() {
	cp ${1} ${1}-bkp
}

# Backup files
backup_file /etc/dnsmasq.conf
backup_file /etc/nginx/html/index.html

# Upgrade
tdnf -y update

# Delete tricky file
rm /etc/systemd/network/99-dhcp-en.network
