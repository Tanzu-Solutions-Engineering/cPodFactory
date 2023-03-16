#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <id_of_edge> <ip_of_peer>" && exit 1 

DATA=/tmp/data

./network/get_bgp.sh ${1} > ${DATA}

cat ${DATA} | tail -n -1 | sed "s/<bgpNeighbour><ipAddress>${2}.*$//" > ${DATA}_HEADER
cat ${DATA} | tail -n -1 | sed "s/${2}<\/ipAddress><protocolAddress>172.16.0.2<\/protocolAddress><forwardingAddress>172.16.0.1<\/forwardingAddress><remoteAS>65001<\/remoteAS><remoteASNumber>65001<\/remoteASNumber><weight>60<\/weight><holdDownTimer>180<\/holdDownTimer><keepAliveTimer>60<\/keepAliveTimer><bgpFilters\/><\/bgpNeighbour>/#TRUC#/" | sed "s/^.*#TRUC#//" > ${DATA}_FOOTER

cat ${DATA}_HEADER > ${DATA}_NEW
echo ${PEER} >> ${DATA}_NEW
cat ${DATA}_FOOTER >> ${DATA}_NEW

./network/put_bgp.sh ${1} ${DATA}_NEW
