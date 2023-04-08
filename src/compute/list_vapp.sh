#!/bin/bash
#bdereims@vmware.com

. ./src/env

PS_SCRIPT=list_vapp.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
${SCRIPT}

echo "List vApp."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:12.4 ${SCRIPT} 

rm -fr ${SCRIPT}
