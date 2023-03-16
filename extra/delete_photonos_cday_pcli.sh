#!/bin/bash
#bdereims@vmware.com

export DOMAIN="cpod-cday.shwrfr.mooo.com"
export VCENTER="vcsa.${DOMAIN}"
export VCENTER_ADMIN="administrator@${DOMAIN}"
export VCENTER_PASSWD="VMware1!"
export TEMPLATE_VM=photonos
export ROOT_PASSWD="VMware1!"
export DATASTORE="Datastore"

PS_SCRIPT=delete_photonos_cday.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp extra/${PS_SCRIPT} ${SCRIPT} 

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###VM_NAME###/${1}/" \
-e "s/###TEMPLATE_VM###/${TEMPLATE_VM}/" \
-e "s/###ROOT_PASSWD###/${ROOT_PASSWD}/" \
-e "s/###DATASTORE###/${DATASTORE}/" \
${SCRIPT}

#docker run --rm -it --dns=10.50.0.3 -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:ubuntu14.04 powershell ${SCRIPT} 2>&1 > /dev/null
docker run --rm --dns=10.50.0.3 -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:ubuntu14.04 powershell ${SCRIPT}

rm -fr ${SCRIPT}
