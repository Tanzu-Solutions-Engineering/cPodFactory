#!/bin/bash
#bdereims@vmware.com

. ./src/env

[ "$1" == "" ] && echo "usage: $0 <cPod Name> )>" && exit 1

HOSTS=/etc/hosts
CPOD=$( echo $1 | tr '[:upper:]' '[:lower:]' ) 

main() {
	cat /etc/hosts | sed -n "/cpod-${CPOD}\t/p" | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print $4}'
}

main $1
