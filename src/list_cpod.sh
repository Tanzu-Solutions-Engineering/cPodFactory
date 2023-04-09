#!/bin/bash
#bdereims@vmware.com

cd "$CPOD_FACTORY" || exit
. ./env

LHEADER=$( echo "${HEADER}" | tr '[:upper:]' '[:lower:]' )

main() {
	echo "List of cPods"
	for CPOD in $( cat ${HOSTS} | grep "${LHEADER}-" | awk '{print $2}' ); do
		FIRST=$( cat /etc/hosts | grep -m 1 "${CPOD}\s" | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print toupper($2),"("$3")"}' )
		LAST=$( cat /etc/dnsmasq.conf | grep -m 1 "\/${CPOD}\." | sed -e "/start/d" -e "s/^.*=\///" -e "s/\/.*$//" )
		FIRST="${FIRST} ......................................................."
		FIRST=$( echo ${FIRST} | cut -c1-40 )
		printf '%s --> %s\n' "${FIRST}" "${LAST}"
	done
}

main $1
