#!/bin/bash
#bdereims@vmware.com

cd /root/cPodFactory
. ./env

LHEADER=$( echo ${HEADER} | tr '[:upper:]' '[:lower:]' )

main() {
	echo "=== List of cPods"
	for CPOD in $( cat ${HOSTS} | grep "${LHEADER}-" | awk '{print $2}' ); do
		FIRST=$( cat /etc/hosts | grep -m 1 "${CPOD}\s" | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print toupper($2),"("$3")"}' )
		LAST=$( cat /etc/dnsmasq.conf | grep -m 1 "\/${CPOD}\." | sed -e "/start/d" -e "s/^.*=\///" -e "s/\/.*$//" )
		FIRST="${FIRST} ......................................................."
		FIRST=$( echo ${FIRST} | cut -c1-40 )
		printf "${FIRST} --> ${LAST}\n"
	done
}

main $1
