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

add_computer_manager() {
        CM_JSON='{
        "server": "'vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
        "origin_type": "vCenter",
        "credential" : {
        "credential_type" : "UsernamePasswordLoginCredential",
        "username": "administrator@'${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
        "password": "'${PASSWORD}'",
        "thumbprint": "'${VCENTERTP}'"
        }
        }'
        SCRIPT="/tmp/CM_JSON"
        echo ${CM_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/fabric/compute-managers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 201 ]
        then
                MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo ${MANAGERSINFO}
        else
                echo "  error setting manager"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

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

# ===== checking nsx version =====
echo
echo "Checking nsx version"
echo

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/node/version)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        VERSIONINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        PRODUCTVERSION=$(echo $VERSIONINFO |jq .product_version)
        echo "  Product: ${PRODUCTVERSION}"
        #Check if 3.2 or 4.1 or better. if not stop script.

else
        echo "  error getting version"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

#======== get venter thubprint ========

VCENTERTP=$(echo | openssl s_client -connect vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}:443 2>/dev/null | openssl x509 -noout -fingerprint -sha256 | cut -d "=" -f2)

# ===== add computer manager =====
# Check existing manager
echo
echo "processing computer manager"
echo
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        MANAGERSCOUNT=$(echo $MANAGERSINFO | jq .result_count)
        if [[ ${MANAGERSCOUNT} -gt 0 ]]
        then
                EXISTINGMNGR=$(echo $MANAGERSINFO| jq -r .results[0].server)
                if [[ "${EXISTINGMNGR}" == "vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}" ]]
                then
                        echo "existing manager set correctly"
                else
                        echo " ${EXISTINGMNGR} does not match vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
                fi
        else
                echo "adding compute manager"
                add_computer_manager
        fi
else
        echo "  error getting managers"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


# ===== Create Uplink profiles =====
# Check existing uplink profiles
# 1 for edge
# 1 for hosts
echo
echo "processing uplink profiles"
echo
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
echo $RESPONSE
echo $HTTPSTATUS

if [ $HTTPSTATUS -eq 200 ]
then
        PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        echo ${PROFILESINFO}
        PROFILESCOUNT=$(echo ${PROFILESINFO} | jq .result_count)
        echo ${PROFILESCOUNT}
        if [[ ${PROFILESCOUNT} -gt 0 ]]
        then
                EXISTINGPROFILES=$(echo $PROFILESINFO| jq -r '.results[].display_name')
                echo $EXISTINGPROFILES
                if [[ "${EXISTINGPROFILES}" == "blahblah" ]]
                then
                        echo "existing manager set correctly"
                else
                        echo " ${EXISTINGPROFILES} does not match blahblah"
                fi
        else
                echo "TODO : adding uplink profiles"
        fi
else
        echo "  error getting uplink profiles"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Create transport zones =====
# Check existing uplink profiles
# 1 for edge
# 1 for hosts
# 1 for overlay
# because we can ! and we are following the NSX best practices

echo
echo "processing transport zones"
echo

echo "get enforcement points"
echo

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
echo $RESPONSE
echo $HTTPSTATUS

if [ $HTTPSTATUS -eq 200 ]
then
        EPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        echo ${EPINFO}
        EPCOUNT=$(echo ${EPINFO} | jq .result_count)
        echo ${EPCOUNT}
        if [[ ${EPCOUNT} -gt 0 ]]
        then
                EXISTINGEP=$(echo $EPINFO| jq -r '.results[].display_name')
                echo $EXISTINGEP
                EXISTINGEPRP=$(echo $EPINFO| jq -r '.results[].relative_path')
                echo $EXISTINGEPRP
                
                if [[ "${EXISTINGEP}" == "default" ]]
                then
                        echo "existing EP is default"
                else
                        echo " ${EXISTINGEP} does not match default"
                fi
        else
                echo "TODO : what when no EP ?"
                exit
        fi
else
        echo "  error getting enforcement-points"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
echo $RESPONSE
echo $HTTPSTATUS

if [ $HTTPSTATUS -eq 200 ]
then
        TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        echo ${TZINFO}
        TZCOUNT=$(echo ${TZINFO} | jq .result_count)
        echo ${TZCOUNT}
        if [[ ${TZCOUNT} -gt 0 ]]
        then
                EXISTINGTZ=$(echo $TZINFO| jq -r '.results[].display_name')
                echo $EXISTINGTZ
                if [[ "${EXISTINGTZ}" == "blahblah" ]]
                then
                        echo "existing manager set correctly"
                else
                        echo " ${EXISTINGTZ} does not match blahblah"
                fi
        else
                echo "TODO : adding uplink profiles"

                exit
        fi
else
        echo "  error getting uplink profiles"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


# ===== transport node profile =====
# Check existing transport node profile
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/transport-node-profiles)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        TNPROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        TNPROFILESCOUNT=$(echo $TNPROFILESINFO | jq .result_count)
        if [[ ${TNPROFILESCOUNT} -gt 0 ]]
        then
                EXISTINGTNPROFILES=$(echo $TNPROFILESINFO| jq -r .results[0].display_name)
                if [[ "${EXISTINGMNGR}" == "vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}" ]]
                then
                        echo "existing manager set correctly"
                else
                        echo " ${EXISTINGMNGR} does not match vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
                fi
        else
                echo "adding TN PROFILES"
                #add_computer_manager
        fi
else
        echo "  error getting managers"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi



# ===== Script finished =====
echo "Configuration done"
