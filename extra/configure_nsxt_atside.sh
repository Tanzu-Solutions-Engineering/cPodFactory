#!/bin/bash
#edewitte@vmware.com

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

### Local vars ####

HOSTNAME=${HOSTNAME_NSX}
NAME=${NAME_NSX}
IP=${IP_NSXMGR}
OVA=${OVA_NSXMGR}

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

[ "${HOSTNAME}" == ""  -o "${IP}" == "" ] && echo "missing parameters - please source version file !" && exit 1

### functions ####

source ./extra/functions.sh

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
VMNAME="${VAPP}-${HOSTNAME}"

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# ===== Start of code =====

NSXFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}
echo ${NSXFQDN}
# ===== Login with basic auth =====
RESPONSE=$(curl -vvv -k -c /tmp/session.txt -X POST -d 'j_username='admin'&j_password='${PASSWORD}'' https://${NSXFQDN}/api/session/create 2>&1 > /dev/null | grep XSRF)
XSRF=$(echo $RESPONSE | awk '{print $3}')
JSESSIONID=$(cat /tmp/session.txt | grep JSESSIONID | rev | awk '{print $1}' | rev)



# ===== Login with basic auth =====
RESPONSE=$(curl -vvv -k -c /tmp/session.txt -X POST -d 'j_username='${NSX_ADMIN}'&j_password='${NSX_PASSWD}'' https://${NSXFQDN}/api/session/create 2>&1 > /dev/null | grep XSRF)
XSRF=$(echo $RESPONSE | awk '{print $3}')
JSESSIONID=$(cat /tmp/session.txt | grep JSESSIONID | rev | awk '{print $1}' | rev)

# ===== checking nsx version =====
echo "Checking nsx version"

RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}" https://${NSXFQDN}/api/v1/node/version)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        VERSIONINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        PRODUCTVERSION=$(echo $VERSIONINFO |jq .product_version)
        echo "  Product: ${PRODUCTVERSION}"
else
        echo "  error getting version"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Script finished =====
echo "Configuration done"

