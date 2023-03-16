#!/bin/bash
#bdereims@vmware.com

# Usage : ./expose_cpod.sh TEST (not cPod-TEST)

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

#========================================================================================

DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts

mutex() {
	while ! mkdir lock 2>&1 > /dev/null
	do
		echo "Waiting (PID $$)..."
		sleep 2 
	done
}

de_mutex() {
	rmdir lock
}

exit_gate() {
	#[ -f lock ] && rm lock
	exit $1
}

check_cpod() {
	echo "rien"
}

affect_public_ip() {
	PUBLIC_IP=$(grep "$(printf '\t')#FREE#$" public-ip | sort | awk '{print $1}' | head -1)

	if [ "X${PUBLIC_IP}" == "X" ]; then
		echo "There is no public IP available."
		de_mutex
		exit_gate 1
	fi

	echo "The Public cPod IP address is '${PUBLIC_IP}'."
}

expose_cpod() {
	echo "rien"
}

main() {
	echo "!!! Work in Progress !!!"
	echo " "
	CPOD=${1}
	check_cpod ${CPOD}

	echo "=== Exposing cPod on Internet."

	mutex
		affect_public_ip ${CPOD}
	de_mutex

	expose_cpod ${CPOD} ${NEW_TRANSIT_IP} ${PUBLIC_IP}

	exit_gate 0
}

main ${1}
