#!/bin/bash
#bdereims@vmware.com

#for squid proxy on cPodRouter
#docker run -d -p 3128:3128 --dns=172.16.1.1 b4tman/squid

. ./env

[ "${1}" == ""  -o "${2}" == "" ] && echo "usage: ${0} CPOD-NAME enable|disable" && exit 1
CPODROUTER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

echo "=== Air-Gapping ${1} with ${2} on cPodRouter" 

rexec() {
	ssh -o LogLevel=ERROR ${CPODROUTER} ${1}
}

case ${2} in
	enable)
		# Accept only RFC1918
		echo ""
		rexec "iptables -P FORWARD DROP ; iptables -A FORWARD -d 10.0.0.0/8 -j ACCEPT ; iptables -A FORWARD -d 172.16.0.0/12 -j ACCEPT ; iptables -A FORWARD -d 192.168.0.0/16 -j ACCEPT ; iptables -xnvL"
		echo ""
		echo "Enable! ${1} now without Internet connectivity."
		;;
	disable)
		echo ""
		rexec "iptables -P FORWARD ACCEPT ; iptables -D FORWARD -d 10.0.0.0/8 -j ACCEPT ; iptables -D FORWARD -d 172.16.0.0/12 -j ACCEPT ; iptables -D FORWARD -d 192.168.0.0/16 -j ACCEPT ; iptables -xnvL"
		echo ""
		echo "Disable! ${1} with Internet connectivity"
		;;
esac
