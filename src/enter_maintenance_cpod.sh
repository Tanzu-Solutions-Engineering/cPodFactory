#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts

exit_gate() {
	rm -fr lock
	exit $1 
}

main() {
	mutex
	echo "=== Enter all ESX in Maintenance Mode for '${1}'."

	

	exit_gate 0
}

main $1 $2
