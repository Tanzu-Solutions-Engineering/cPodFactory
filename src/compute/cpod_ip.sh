#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} CPOD-NAME" && exit 1

DNSMASQ=/etc/dnsmasq.conf
CPOD_L=$( echo ${1} | tr '[:upper:]' '[:lower:]' )
CPOD_H=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
HEADER_L=$( echo ${HEADER} | tr '[:upper:]' '[:lower:]' )
CPOD_L=$( echo ${CPOD_L} | sed "s/${HEADER_L}-//" )

CONF=$( grep --fixed-strings "cpod-${CPOD_L}." ${DNSMASQ} )
[ $? -ne 0 ] && echo "error: cPod ${1} not found!" && exit 1
	
TRANSIT_IP=$( echo ${CONF} | sed 's!^.*/!!' | sort | tail -n 1 )

if [ "${2}" == "ontransit" ]; then
	echo "${TRANSIT_IP}"
else	
	TMP=$( echo ${TRANSIT_IP} | sed 's/.*\.//' )
#	TMP=$( expr $TMP - 10 )

	echo "${TRANSIT}.${TMP}"
fi
