#!/bin/bash
#edewitte@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod MAZ Mgmt Name>  <owner email>" && exit 1

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


if [ ! -f ./licenses.key ]; then
	echo "./licenses.key does not exist. please create one by using the licenses.key.template as reference"
	exit
else
	source ./licenses.key
fi

[ "${LIC_NSXT}" == ""  -o "${LIC_NSXT}" == "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" ] && echo "LIC_NSXT not set - please check licenses.key file !" && exit 1

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

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

if [ ${VLAN} -gt 40 ]; then
	TEPVLANID=${VLAN}3
        UPLINKSVLANID=${VLAN}4
else
	TEPVLANID=${VLAN}03
        UPLINKSVLANID=${VLAN}04
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# ===== Start of code =====

echo
echo "========================="
echo "Configuring NSX-T manager"
echo "========================="
echo

NSXFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}
echo ${NSXFQDN}

echo "  waiting for nsx mgr to answer ping"
echo 

STATUS=$( ping -c 1 ${NSXFQDN} 2>&1 > /dev/null ; echo $? )
printf "\t ping nsx ."
while [[ ${STATUS} != 0  ]]
do
        sleep 10
        STATUS=$( ping -c 1 ${NSXFQDN} 2>&1 > /dev/null ; echo $? )
        printf '.' >/dev/tty
done
echo
echo
loop_wait_nsx_manager_status

# ===== checking nsx version =====
echo
echo "Checking nsx version"
echo

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/node/version)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        VERSIONINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        PRODUCTVERSION=$(echo $VERSIONINFO |jq -r .product_version)
        echo "  Product: ${PRODUCTVERSION}"
        #Check if 3.2 or 4.1 or better. if not stop script.
        MAJORVERSION=$(echo ${PRODUCTVERSION} | head -c1)
        MINORVERSION=$(echo ${PRODUCTVERSION} | head -c3)
       	case $MAJORVERSION in
		3)
		        LOWESTVERSION=$(printf "%s\n" "3.2" ${MINORVERSION} | sort -V | head -n1)
                        echo "  lowestversion: $LOWESTVERSION"
                        if [[ "${LOWESTVERSION}" == "3.2" ]]
                        then
                                echo "  Version is at lease 3.2"
                        else
                                echo "  Version is below 3.2. Script uses newer API (>3.2 or >4.1). stopping here."
                                exit
                        fi
			;;
		4)
		        LOWESTVERSION=$( printf "%s\n" "4.1" ${MINORVERSION} | sort -V | head -n1)
                        echo "lowestversion: $LOWESTVERSION"
                        if [[ "${LOWESTVERSION}" == "4.1" ]]
                        then
                                echo "  Version is at lease 4.1"
                        else
                                echo "  Version is below 4.1. Script uses newer API (>3.2 or >4.1). stopping here."
                                exit
                        fi			
			;;
		*)
		        echo "This script is not ready yet for nsx-t version $MAJORVERSION"
                        exit
		        ;;
	esac

else
        echo "  error getting version"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


#======== Accept Eula ========
echo
echo "Accepting EULA and settting CEIP"
echo

nsx_accept_eula

#======== License NSX-T ========

#check License
echo
echo "Checking NSX Licenses"
echo
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/licenses)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        LICENSESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        LICENSESCOUNT=$(echo $LICENSESINFO | jq .result_count)
        if [[ ${LICENSESCOUNT} -gt 0 ]]
        then
                EXISTINGLIC=$(echo ${LICENSESINFO} |jq '.results[] | select (.description =="NSX Data Center Enterprise Plus")')
                if [[ "${EXISTINGLIC}" == "" ]]
                then
                        echo "  No NSX datacenter License present."
                        echo "  adding NSX license"
                        add_nsx_license
                else
                        echo "  NSX Datacenter license present. proceeding with configuration"
                fi
        else
                echo "  No License assigned."
                echo "  add NSX License"
                add_nsx_license                
        fi
else
        echo "  error getting licenses"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


#======== get venter thumbprint ========

VCENTERTP=$(echo | openssl s_client -connect vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}:443 2>/dev/null | openssl x509 -noout -fingerprint -sha256 | cut -d "=" -f2)

# ===== add computer manager =====
# Check existing manager
echo
echo "Processing computer manager"
echo

MGRNAME="vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
MGRTEST=$(get_compute_manager "${MGRNAME}")

if [ "${MGRTEST}" != "" ]
then
        echo "  ${MGRTEST}"
        MGRID=$(get_compute_manager_id "${MGRNAME}")
        #get_compute_manager_status "${MGRID}"
        loop_wait_compute_manager_status "${MGRID}"
else
        echo "  Adding Compute Manager"
        add_computer_manager "${MGRNAME}"
        sleep 30
        MGRID=$(get_compute_manager_id "${MGRNAME}")
        loop_wait_compute_manager_status "${MGRID}"
fi

# ===== Script finished =====
echo "Init Configuration done"
