#!/bin/bash
#bdereims@vmware.com

DATASTORE="$( echo ${1} | sed -e "s/-//g" )Datastore"
ssh ${1} "esxcli system coredump file add -d ${DATASTORE} ; esxcli system coredump file set --smart --enable true"
