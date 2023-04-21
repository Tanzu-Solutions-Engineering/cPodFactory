#!/bin/bash
#jacobssimon@vmware.com

# ELM
# export PSC_DOMAIN
# export PSC_PASSWORD

. ./env
. ./licenses.key

[ "$1" == "" ] && echo "usage: $0 <name of cpod>, then the script automatically license vCenter, vSphere and vSAN if any" && exit 1

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
# Local Functions

add_licenses(
	echo "Connecting vcsa.${POD_FQDN} ..."
	for i in {0..4}
	do
		govc license.add -k=true ${KEYS[i]}
	done
	govc license.ls -k=true
)
apply_license_vcenter(
	govc license.assign -k=true ${KEYS[0]}
)

apply_licenses_hosts(
	NUM_ESX=$(govc datacenter.info -k=true "${POD_NAME}" | grep "Hosts" | cut -d : -f 2 | cut -d " " -f 14)
	
	for (( i=1; i<=$NUM_ESX; i++ ))
	do
		HOST="esx-0${i}.${POD_FQDN}"
		govc license.assign -k=true -host ${HOST,,} ${KEYS[1]}
	done
)
#======================================

VCENTER_VERSION=$(govc about |grep Version | awk '{print $2}' |cut -d "." -f1)

case $VCENTER_VERSION in
		7)
			VCENTER_KEY=$V7_VCENTER_KEY
			ESX_KEY=$V7_ESX_KEY
			VSAN_KEY=$V7_VSAN_KEY
			add_licenses
			apply_license_vcenter
			apply_licenses_hosts
			;;
		8)
			VCENTER_KEY=$V8_VCENTER_KEY
			ESX_KEY=$V8_ESX_KEY
			VSAN_KEY=$V8_VSAN_KEY
			add_licenses
			apply_license_vcenter
			apply_licenses_hosts
			;;
		*)
		echo "Version $VCENTER_VERSION not foreseen yet by script"
		;;
	esac
