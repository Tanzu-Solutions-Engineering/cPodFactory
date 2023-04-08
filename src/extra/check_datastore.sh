#!/bin/bash
#bdereims@vmware.com

source ./env
. ./govc_env

CLUSTER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )

DATASTOREFREE=$( govc datastore.info ${DATASTORE} | grep Free | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g" )
DATASTOREFREE=$( echo "${DATASTOREFREE}/1" | bc )
DATASTOREFREE=$( expr ${DATASTOREFREE} )

if [ ${DATASTOREFREE} -lt 10000 ]; then
	echo "No more space!"
	exit 1
fi

echo "Ok!"
exit 0
