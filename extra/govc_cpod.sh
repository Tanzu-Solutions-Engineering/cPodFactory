#!/bin/bash
#edewitte@vmware.com

#generate govc_env for cpod in /tmp

source ./env

[ "$1" == "" ] && echo "usage: $0 <name of cpod>, then the script generates a govc env file in /tmp" && exit 1


#==========CONNECTION DETAILS==========
NAME="$( echo ${1} | tr '[:lower:]' '[:upper:]' )"
POD_NAME="cPod-${1}"
POD_NAME_LOWER="$( echo ${POD_NAME} | tr '[:upper:]' '[:lower:]' )"
POD_FQDN="${POD_NAME_LOWER}.${ROOT_DOMAIN}"

SCRIPT=/tmp/scripts/govc_${POD_NAME}


if [ -z ${PSC_DOMAIN} ]; then
	echo export GOVC_USERNAME="administrator@${POD_FQDN}" >> ${SCRIPT}
else
	echo export GOVC_USERNAME="administrator@${PSC_DOMAIN}" >> ${SCRIPT}
fi

if [ -z ${PSC_DOMAIN} ]; then
	echo export GOVC_PASSWORD="$( ./extra/passwd_for_cpod.sh ${1} )" >> ${SCRIPT}
else
	echo export GOVC_PASSWORD="${PSC_PASSWORD}" >> ${SCRIPT}
	VCENTER_CPOD_PASSWD=${PSC_PASSWORD}
fi

echo export GOVC_URL="https://${GOVC_USERNAME}:${GOVC_PASSWORD}@vcsa.${POD_FQDN}" >> ${SCRIPT}
echo export GOVC_DATACENTER="" >> ${SCRIPT}

echo "govc_env script available at : ${SCRIPT}"