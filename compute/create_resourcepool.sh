#!/bin/bash
#bdereims@vmware.com

# $1 : cPod Name
# $2 : PortGroup Name
# $3 : @IP
# $4 : # of ESX
# $5 : Root Domain
# $6 : Owner 
# $7 : Start Number ESX, for adding ESX on created cPod

. ./env

[ "$1" == "" -o "$2" == "" -o "$3" == "" ] && echo "usage: $0 <name_of_vapp> <name_of_port_group> <ip_on_transit> <num_esx> <root domain> <owner> <start number esx>" && exit 1 

PS_SCRIPT=create_resourcepool.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###PORTGROUP###/${2}/" \
-e "s/###CPOD_NAME###/${1}/" \
-e "s/###TEMPLATE_VM###/${TEMPLATE_VM}/" \
-e "s/###TEMPLATE_ESX###/${TEMPLATE_ESX}/" \
-e "s/###IP###/${3}/" \
-e "s/###ROOT_PASSWD###/${ROOT_PASSWD}/" \
-e "s/###DATASTORE###/${DATASTORE}/" \
-e "s/###NUMESX###/${4}/" \
-e "s/###ROOT_DOMAIN###/${5}/" \
-e "s/###ASN###/${ASN}/" \
-e "s/###OWNER###/${6}/" \
-e "s/###STARTNUMESX###/${7}/" \
${SCRIPT}

echo "Creating ResourcePool '${HEADER}-${1}' with ${4} Nested ESXi."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT} 2>&1 > /dev/null

#rm -fr ${SCRIPT}
