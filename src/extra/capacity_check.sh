#!/bin/bash

. ./govc_env
. ./env

if [ "${FORCE}" == "1" ]; then
	echo "Ok!"
	exit 0
fi

CLUSTER=$( echo $CLUSTER | tr '[:lower:]' '[:upper:]' )

VSANFREE=$( govc datastore.info ${DATASTORE} | grep Free | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g" )
VSANFREE=$( echo "${VSANFREE}/1" | bc )
VSANFREE=$( expr ${VSANFREE} )

VSANCAP=$( govc datastore.info ${DATASTORE} | grep Capacity | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g" )
VSANCAP=$( echo "${VSANCAP}/1" | bc )
VSANCAP=$( expr ${VSANCAP} )

STORAGECAP=$(awk "BEGIN {printf \"%.2f\n\",(1-$VSANFREE/$VSANCAP)*100}")
echo "Free Storage on ${DATASTORE} : ${STORAGECAP} %"


if [ $(echo ${STORAGECAP}'>'$((80)) | bc) ] 
then
	echo "No enough datastore space!"
	exit 1
fi

MEM=$( govc metric.sample "host/${VCENTER_CLUSTER}" mem.usage.average | sed -e "s/,.*$//" | cut -f9 -d" " | cut -f1 -d"." )
MEM=$( expr ${MEM} )

if [ $(echo ${STORAGECAP}'>'$((80)) | bc) ] || [ 80 -lt ${MEM} ]
then
	echo "No more space!"
	exit 1
fi

echo "Ok!"
exit 0
