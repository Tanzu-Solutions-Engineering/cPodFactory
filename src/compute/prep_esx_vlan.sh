#!/bin/bash
#bdereims@vmware.com

# $1 : cPod Name

. ./src/env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

PS_SCRIPT=prep_esx_vlan.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###CPOD_NAME###/${CPOD_NAME}/" \
-e "s/###PASSWORD###/${PASSWORD}/" \
-e "s/###VLAN###/${VLAN}/" \
${SCRIPT}

# esxcli network vswitch standard portgroup set -p "VM Network" --vlan-id 14
# esxcli network vswitch standard portgroup set -p "Management Network" --vlan-id 14 ; exit

for ESX in $( ssh ${NAME_LOWER} "cat /etc/hosts | cut -f2 | grep esx" ); do
	ESX_FQDN="${ESX}.${NAME_LOWER}.${ROOT_DOMAIN}"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "esxcli network vswitch standard portgroup set -p \"VM Network\" --vlan-id ${VLAN}" 2>&1 > /dev/null
	nohup sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "esxcli network vswitch standard portgroup set -p \"Management Network\" --vlan-id ${VLAN}" 2>&1 > /dev/null &
	#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "esxcli network vswitch standard portgroup list"
done

echo "Modifying ESX of '${HEADER}-${1}'."
#docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT} 2>&1 > /dev/null
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}

rm -fr ${SCRIPT}
