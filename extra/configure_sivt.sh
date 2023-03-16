#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name> <owner email>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### functions ####

source ./extra/functions.sh

### Local vars ####

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$vlan = '###VLAN###'

HOSTNAME=${HOSTNAME_SIVT}
NAME=${NAME_SIVT}
IP=${IP_SIVT}

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
#        ./extra/post_slack.sh ":wow: *${2}* you're not allowed to deploy in *${NAME_HIGHER}*"
        exit 1
fi

CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"


STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
#        ./extra/post_slack.sh ":wow: Are you sure that VCSA is not already deployed in ${1}. Something have the same @IP."
        exit 1
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

# generate arcas json for cpod

# transfer json

# start arcas

root@photon-machine [ /opt/vmware/arcas/src ]# arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgm.json --avi_configuration --tkg_mgmt_configuration --shared_service_configuration --workload_preconfig --workload_deploy --deploy_extensions --verbose


#rm ${MYSCRIPT}
