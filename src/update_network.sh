#!/bin/bash

#exit 0

. ./env

CPOD=$( cat zz | grep "172.16" | grep "cpod-" | awk '{print $1}' )

for THEIP in $CPOD;
do
	CPODASN=$( echo ${THEIP} | cut -f4 -d"." )
	CPODASN=$( expr ${ASN} + ${CPODASN} )	
	echo ${THEIP} ${ASN} ${CPODASN}

	scp update_network_cpodrouter.sh ${THEIP}:.
	ssh ${THEIP} "bash update_network_cpodrouter.sh ${CPODASN}"
	
	./network/delete_bgp_peer_vtysh.sh ${THEIP} 65201
	./network/add_bgp_peer_vtysh.sh ${THEIP} ${CPODASN} 

done
