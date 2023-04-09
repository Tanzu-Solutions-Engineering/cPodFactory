#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod> <owner's email alias (ex: bdereims)>" && exit 1 

if [ "${2}" ==  "" ]; then
	OWNER="admin"
else
	OWNER="${2}"
fi

DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts

mutex() {
	while ! mkdir lock 2>&1 > /dev/null
	do
		echo "Waiting (PID $$)..."
		sleep 2
	done
}

network_delete() {
	case "${BACKEND_NETWORK}" in
	NSX-V)
		${NETWORK_DIR}/delete_logicalswitch.sh ${1} ${2}
		;;
	NSX-T)
		${NETWORK_DIR}/delete_logicalswitch.sh ${1} ${2}
		;;
	VLAN)
		${NETWORK_DIR}/delete_vlan_portgroup.sh ${2}
		;;
	esac
}

respool_delete() {
	${COMPUTE_DIR}/delete_resourcepool.sh ${1}
}

modify_dnsmasq() {
	echo "Modifying '${DNSMASQ}' and '${HOSTS}'."
	IPTRANSIT=$( ${COMPUTE_DIR}/cpod_ip.sh ${1} ontransit )
	sed -i "/${1}\./d" ${DNSMASQ} 
	sed -i "/srv-host=_aserv._tcp,${IPTRANSIT},9100/d" ${DNSMASQ} 
	sed -i "/\t${1}\t/d" ${HOSTS} 

	systemctl stop dnsmasq 
        systemctl start dnsmasq
}

bgp_delete_peer() {
	./network/delete_bgp_neighbour.sh edge-6 ${1}
}

bgp_delete_peer_vtysh() {
        ./network/delete_bgp_peer_vtysh.sh ${1} ${2}
}

release_mutex() {
	rmdir lock
}

exit_gate() {
	exit $1 
}

test_owner() {
	LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
	if [ "${LINE}" != "" ] && [ "${LINE}" != "${OWNER}" ]; then
		echo "Error: Not Ok for deletion"
		./extra/post_slack.sh ":wow: *${OWNER}* you're not allowed to delete *${NAME_HIGH}*"
		exit 1
	fi
}

main() {
	CPOD_NAME="cpod-$1"
	CPOD_NAME_HIGH=$( echo ${CPOD_NAME} | tr '[:lower:]' '[:upper:]' )
        CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
	NAME_HIGH=$( echo $1 | tr '[:lower:]' '[:upper:]' )

	test_owner ${2}

	./extra/post_slack.sh "Deleting cPod *${NAME_HIGH}*"

	echo "=== Deleting cPod called '${NAME_HIGH}'."

	IP=$( cat ${HOSTS} | grep ${CPOD_NAME_LOWER} | cut -f1 )
	TMP=$( echo ${IP} | cut -d"." -f4 )
	ASN=$( expr ${ASN} + ${TMP} )

	mutex
		#bgp_delete_peer ${IP}
		bgp_delete_peer_vtysh ${IP} ${ASN} 
		modify_dnsmasq ${CPOD_NAME_LOWER}
	release_mutex

	respool_delete ${NAME_HIGH}
	sleep 5
	network_delete ${NSX_TRANSPORTZONE} ${CPOD_NAME_LOWER}

	./cpod_lease.sh delete ${1} ${OWNER}
	
	echo "=== Deletion is finished."
	./extra/post_slack.sh ":thumbsup: cPod *${NAME_HIGH}* has been deleted"
	exit_gate 0
}

main $1
