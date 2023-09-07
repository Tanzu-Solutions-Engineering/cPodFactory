#!/bin/bash
#edewitte@vmware.com

source  ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name>  <owner email>" && exit 1

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
source ./extra/functions_nsxt.sh

###################
CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
VMNAME="${VAPP}-${HOSTNAME}"
CPODROUTERIP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ${CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)


NSXFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}
echo ${NSXFQDN}


NSX_ADMIN=admin
NSX_PASSWD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

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

# ===== checking user admin =====
echo "Checking user Admin"
RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}" https://${NSXFQDN}/api/v1/node/users)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        USERINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        echo $USERINFO | jq -r '["NAME","STATUS","PWD Freq","ID"], ["----","------","--------","--"], (.results[] | [.username, .status, .password_change_frequency, .userid]) | @tsv' | column -t -s $'\t'
        COUNTOFRISKS=$(echo $USERINFO |jq '.results[] | select (.password_change_frequency <100)| .userid' | wc -l)
        if [[ $COUNTOFRISKS > 0 ]]; then 
                echo "Fixing users with pwd freq <100"
                SHORTPWDUSERS=$(echo $USERINFO | jq '.results[] | select (.password_change_frequency <100)| .userid')
                for USERID in $SHORTPWDUSERS; do
                        #echo "curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H \"X-XSRF-TOKEN: ${XSRF}\" --data-binary '{ \"password_change_frequency\": 9999 }' https://${NSX}/api/v1/node/users/${USERID}"
                        RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}"  -X PUT -H 'Content-Type: application/json' --data-binary '{ "password_change_frequency": 9999 }' https://${NSXFQDN}/api/v1/node/users/${USERID})
                        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
                        if [ $HTTPSTATUS -eq 200 ]
                        then
                                echo "success for ${USERID}"
                        else
                                echo "error setting user ${USERID}"
                                echo ${HTTPSTATUS}
                                echo ${RESPONSE}
                                exit
                        fi
                done
        else
                echo
                echo "No issues identified that require fixing"

        fi
else
        echo "error getting users"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi
 