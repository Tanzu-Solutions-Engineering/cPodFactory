#!/bin/bash

. ./env
. ./govc_env


if [ "${FORCE}" == "1" ]; then
	echo "Ok!"
	exit 0
fi

CLUSTER=$( echo $CLUSTER | tr '[:lower:]' '[:upper:]' )

VSAN=$( govc datastore.info ${DATASTORE} | grep Free | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g" )
VSAN=$( echo "${VSAN}/1" | bc )
VSAN=$( expr ${VSAN} )

MEM=$( govc metric.sample "host/${VCENTER_CLUSTER}" mem.usage.average | sed -e "s/,.*$//" | cut -f9 -d" " | cut -f1 -d"." )
MEM=$( expr ${MEM} )

if [ 10000 -gt ${VSAN} ] || [ 80 -lt ${MEM} ]
then
	echo "No more space!"
	exit 1
fi

echo "Ok!"
exit 0
