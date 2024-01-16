#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] || [ "$2" == "" ] && echo "usage: $0 <name_of_vcf_cpod> wldname "  && echo "usage example: $0 vcf45 wld01" && exit 1

source ./extra/functions.sh

source ./extra/functions_sddc_mgr.sh

EDGECLUSTER_JSON_TEMPLATE=./compute/sddc_edgecluster.json
#Management Domain CPOD
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )

case "${BACKEND_NETWORK}" in
    NSX-T)
        echo "NSX-T Backend"
        echo "VLAN_MGMT=0"
        VLAN_MGMT="0"
        ;;
    VLAN)
        VLANID=$( expr ${BACKEND_VLAN_OFFSET} + ${VLAN_MGMT} )
        VLAN_MGMT=${VLANID}
        echo "VLAN Backend"
        echo "VLAN_MGMT=${VLANID}"
        ;;
esac

WLDNAME="${2}"
#CLUSTERNAME="${3}"

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

#Check edgecluster json exists
SCRIPT=/tmp/scripts/edgecluster-${WLDNAME}-${NAME_LOWER}.json

if [ ! -f "${SCRIPT}" ]
then
        echo "Edge cluster json for ${WLDNAME} does not exist at ${SCRIPT}"
        echo "bailing out."
        exit 1
fi

echo
echo "Getting VCF API Token"
TOKEN=$(sddc_get_token "${NAME_LOWER}" "${PASSWORD}" )

# Checking not running edgecluster
echo
EDGECLUSTERS=$(sddc_edgecluster_get)
if [[ $(echo "${EDGECLUSTERS}" | jq '.elements[]') != "" ]]
then
        echo "There is an existing edge cluster defined"
        echo
        echo "${EDGECLUSTERS}" | jq '.elements[]'
        exit 1
else
        echo "No existing edge cluster present. Proceeding to creation"
fi

echo
echo "Creating Edge Cluster"
EDGECREATE=$(sddc_edgecluster_create "${SCRIPT}")

echo "$EDGECREATE" 
echo
EDGECREATEID=$(echo "${EDGECREATE}" | jq -r '.id')

sddc_loop_wait_commissioning "${EDGECREATEID}"