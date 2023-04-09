#!/bin/bash
#bdereims@vmware.com

# $1 : cPod Name

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>"  && exit 1 

PS_SCRIPT=put_esx_maintenance_mode.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

NAME_LOWER=$( echo $1 | tr '[:upper:]' '[:lower:]' )
VCENTER="vcsa.cpod-${NAME_LOWER}.${ROOT_DOMAIN}"

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_CPOD_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###CPOD_NAME###/${1}/" \
${SCRIPT}

echo "Enter all ESX in Maintenace Mode for '${1}'."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:12.4 ${SCRIPT} 

rm -fr ${SCRIPT}
