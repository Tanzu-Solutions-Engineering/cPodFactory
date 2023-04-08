#!/bin/bash
#bdereims@vmware.com

. ./src/env

[ "$1" == "" ] && echo "usage: $0 <name_of_portgroup>" && exit 1 

PS_SCRIPT=modify_portgroup.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###PORTGTOUP###/${1}/" \
${SCRIPT}

#echo "Modifying '${1}' with Promiscuous and ForgedTransmits."
echo "Modifying '${1}' with MacLearn and ForgedTransmits."
#docker run --rm -it -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:ubuntu14.04 powershell ${SCRIPT} 2>&1 > /dev/null
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore ${SCRIPT} 2>&1 > /dev/null

rm -fr ${SCRIPT}
