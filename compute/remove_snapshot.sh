#!/bin/bash
#@vtonevvmware.com

# $1 : cPod Name

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cPod> <snapshot_name> to delete" && exit 1 

PS_SCRIPT=remove_snapshot.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT} 

IP=$( ${COMPUTE_DIR}/cpod_ip.sh ${1} )
IP="${IP}.2"
GEN_PASSWD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

sed -i -e "s/###VCENTER###/${VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${VCENTER_CLUSTER}/" \
-e "s/###PORTGROUP###/${2}/" \
-e "s/###CPOD_NAME###/${1}/" \
-e "s/###TEMPLATE_FILER###/${TEMPLATE_FILER}/" \
-e "s/###IP###/${IP}/" \
-e "s/###ROOT_PASSWD###/${ROOT_PASSWD}/" \
-e "s/###DATASTORE###/${DATASTORE}/" \
-e "s/###ROOT_DOMAIN###/${3}/" \
-e "s/###GEN_PASSWD###/${GEN_PASSWD}/" \
${SCRIPT}

echo "Removing snapshot for VMs of '${HEADER}-${1}'."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -i -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}  
echo "Touching vsan.out to dirty"
#this makes refresh the used size calculation
compute/vsan_objects.sh touch



#rm -fr ${SCRIPT}
echo ${SCRIPT}
