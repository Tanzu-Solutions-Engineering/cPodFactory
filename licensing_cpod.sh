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

add_licenses() {
	echo "adding license ..."
	govc license.add $VCENTER_KEY
	govc license.add $ESX_KEY
	govc license.add $VSAN_KEY
	govc license.ls
}

apply_license_vcenter() {
	echo "Applying vCenter license ..."
	govc license.assign  $VCENTER_KEY
}

apply_licenses_hosts() {
	NUM_ESX=$(govc datacenter.info "${POD_NAME}" | grep "Hosts" | cut -d : -f 2 | cut -d " " -f 14)
	
	for (( i=1; i<=$NUM_ESX; i++ ));
	do
		HOST="esx0${i}.${POD_FQDN}"
		govc license.assign -host ${HOST,,} ${ESX_KEY}
	done
}

apply_licenses_clusters() {
	CLUSTERS=$(govc ls -t ClusterComputeResource host |cut -d "/" -f4)
	
	for CLUSTER in $CLUSTERS;
	do
		govc license.assign -cluster $CLUSTER $VSAN_KEY
	done
}


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
		apply_licenses_clusters
		;;
	8)
		VCENTER_KEY=$V8_VCENTER_KEY
		ESX_KEY=$V8_ESX_KEY
		VSAN_KEY=$V8_VSAN_KEY
		add_licenses
		apply_license_vcenter
		apply_licenses_hosts
		apply_licenses_clusters
		;;
	*)
		echo "Version $VCENTER_VERSION not foreseen yet by script"
		;;
esac
