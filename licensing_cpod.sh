#!/bin/bash
#jacobssimon@vmware.com

# ELM
# export PSC_DOMAIN
# export PSC_PASSWORD

. ./env
. ./licenses.key

[ "$1" == "" ] && echo "usage: $0 <name of cpod>, then the script automatically license vCenter, vSphere and vSAN if any" && exit 1

#==========LICENSE KEYS==========

#vCenter 6 std 16 CPUs exp 04/2021
#KEYS[0]=XXX

#vSphere 6 ent plus 64 cpus exp 04/2021
#KEYS[1]=XXX

#vSan 6 ent 32 cpus exp 01/2020
KEYS[2]=XXX

#NSX V Ent 32 cpus never exp
KEYS[3]=XXX

#==========CONNECTION DETAILS==========

NAME="$( echo ${1} | tr '[:lower:]' '[:upper:]' )"
POD_NAME="cPod-${1}"
POD_NAME_LOWER="$( echo ${POD_NAME} | tr '[:upper:]' '[:lower:]' )"
POD_FQDN="${POD_NAME_LOWER}.${ROOT_DOMAIN}"

if [ -z ${PSC_DOMAIN} ]; then
	GOVC_LOGIN="administrator@${POD_FQDN}"
else
	GOVC_LOGIN="administrator@${PSC_DOMAIN}"
fi

if [ -z ${PSC_DOMAIN} ]; then
	GOVC_PWD="$( ./extra/passwd_for_cpod.sh ${1} )"
else
	GOVC_PWD="${PSC_PASSWORD}"
	VCENTER_CPOD_PASSWD=${PSC_PASSWORD}
fi

export GOVC_URL="https://${GOVC_LOGIN}:${GOVC_PWD}@vcsa.${POD_FQDN}"

#======================================

main() {
	echo "Connecting vcsa.${POD_FQDN} ..."
	
	for i in {0..4}
	do
		govc license.add -k=true ${KEYS[i]}
	done
	govc license.assign -k=true ${KEYS[0]}
	
	NUM_ESX=$(govc datacenter.info -k=true "${POD_NAME}" | grep "Hosts" | cut -d : -f 2 | cut -d " " -f 14)
	
	for (( i=1; i<=$NUM_ESX; i++ ))
	do
		HOST="esx-0${i}.${POD_FQDN}"
		govc license.assign -k=true -host ${HOST,,} ${KEYS[1]}
	done
	
	govc license.ls -k=true
}

main
