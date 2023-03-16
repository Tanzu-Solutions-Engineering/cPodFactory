#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <owner's email alias (ex: bdereims)>" && exit 1

if [ "${2}" ==  "" ]; then
	OWNER="admin"
else
	OWNER="${1}"
fi

HOSTS=/etc/hosts

main() {
	echo "=== List of cPod Password"
	cat /etc/hosts | grep ${1} | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print toupper($2),": "$4}'
}

main $1
