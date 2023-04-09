#!/bin/bash
#bdereims@vmware.com

# Usage: remove_orphaned.sh EUC

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cdpod>" && exit 1

CPOD_NAME=$( echo $1 | tr '[:upper:]' '[:lower:]' )
CPOD_VCENTER_ADMIN="administrator@vsphere.local"
CPOD_VCENTER_DATACENTER="${1}"
CPOD_VCENTER_CLUSTER="Cluster"
CPOD_DOMAIN="${CPOD_NAME}.${ROOT_DOMAIN}"
CPOD_VCENTER="vcsa.${CPOD_DOMAIN}"

PS_SCRIPT=remove_orphaned.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT}

sed -i -e "s/###VCENTER###/${CPOD_VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${CPOD_VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_CPOD_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${CPOD_VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${CPOD_VCENTER_CLUSTER}/" \
-e "s/###DOMAIN###/${CPOD_DOMAIN}/" \
${SCRIPT}

echo "Preparing vCenter of ${1}'."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:12.4 ${SCRIPT}

rm -fr ${SCRIPT}
