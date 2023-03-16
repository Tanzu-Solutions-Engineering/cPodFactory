#!/bin/bash
#bdereims@vmware.com

# Usage: prep_vcsa.sh EUC
###
# ELM
# export PSC_DOMAIN
# export PSC_PASSWORD

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod> <num_of_esx>" && exit 1

CPOD_NAME=$( echo $1 | tr '[:upper:]' '[:lower:]' )
CPOD_NAME="cpod-${CPOD_NAME}"
CPOD_VCENTER_DATACENTER="cPod-$( echo $1 | tr '[:lower:]' '[:upper:]' )"
CPOD_VCENTER_CLUSTER="Cluster"
CPOD_DOMAIN="${CPOD_NAME}.${ROOT_DOMAIN}"
CPOD_VCENTER="vcsa.${CPOD_DOMAIN}"
CPOD_VCENTER_ADMIN="administrator@${CPOD_DOMAIN}"

if [ -z ${PSC_DOMAIN} ]; then
	CPOD_VCENTER_ADMIN="administrator@${CPOD_DOMAIN}"
else
	CPOD_VCENTER_ADMIN="administrator@${PSC_DOMAIN}"
fi

PS_SCRIPT=prep_vcsa.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${COMPUTE_DIR}/${PS_SCRIPT} ${SCRIPT}

ESX_CPOD_PASSWD=$( ./extra/passwd_for_cpod.sh ${1} )

if [ -z ${PSC_DOMAIN} ]; then
	VCENTER_CPOD_PASSWD=${ESX_CPOD_PASSWD}
else
	VCENTER_CPOD_PASSWD=${PSC_PASSWORD}
fi

sed -i -e "s/###VCENTER###/${CPOD_VCENTER}/" \
-e "s/###VCENTER_ADMIN###/${CPOD_VCENTER_ADMIN}/" \
-e "s/###VCENTER_PASSWD###/${VCENTER_CPOD_PASSWD}/" \
-e "s/###ESX_PASSWD###/${ESX_CPOD_PASSWD}/" \
-e "s/###VCENTER_DATACENTER###/${CPOD_VCENTER_DATACENTER}/" \
-e "s/###VCENTER_CLUSTER###/${CPOD_VCENTER_CLUSTER}/" \
-e "s/###DOMAIN###/${CPOD_DOMAIN}/" \
-e "s/###NUMESX###/${2}/" \
${SCRIPT}

echo "Preparing vCenter of ${1}'."
docker run --rm --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v ${SCRIPT_DIR}:${SCRIPT_DIR} vmware/powerclicore:ubuntu16.04 ${SCRIPT}

rm -fr ${SCRIPT}
echo ${SCRIPT}
