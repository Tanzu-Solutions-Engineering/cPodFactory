#!/bin/bash
#goldyck@vmware.com

# $1 : cPod Name
# This scrips generates an ems json for cloudbuilder and creates DNS entries in the cpod mostly used if you want to do the deployment by hand.
# source helper functions

. ./env
source ./extra/functions.sh

#input validation check
if [ $# -ne 1 ]; then
  echo "usage: $0 <name_of_cpod>"
  echo "usage example: $0 LAB01" 
  exit 1
fi

#build the variables
CPODROUTER=$( echo "${HEADER}-${1}" | tr '[:upper:]' '[:lower:]' )
CPOD_NAME=$( echo "${1}" | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo "${HEADER}"-"${CPOD_NAME}" | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./"${COMPUTE_DIR}"/cpod_ip.sh "${1}" )
PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 
SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/cloudbuilder-${NAME_LOWER}.json

# with NSX, VLAN Management is untagged
if [ ${BACKEND_NETWORK} != "VLAN" ]; then
	VLAN_MGMT="0"
fi

if [ ${VLAN} -gt 40 ]; then
	VMOTIONVLANID=${VLAN}1
	VSANVLANID=${VLAN}2
	TRANSPORTVLANID=${VLAN}3
else
	VMOTIONVLANID=${VLAN}01
	VSANVLANID=${VLAN}02
	TRANSPORTVLANID=${VLAN}03
fi

#Create the EMS
mkdir -p ${SCRIPT_DIR}
cp ${COMPUTE_DIR}/${EMS_TEMPLATE} ${SCRIPT}

# Generate JSON for cloudbuilder
sed -i -e "s/###SUBNET###/${SUBNET}/g" \
-e "s/###PASSWORD###/${PASSWORD}/" \
-e "s/###VLAN###/${VLAN}/g" \
-e "s/###VMOTIONVLANID###/${VMOTIONVLANID}/g" \
-e "s/###VSANVLANID###/${VSANVLANID}/g" \
-e "s/###TRANSPORTVLANID###/${TRANSPORTVLANID}/g" \
-e "s/###VLAN_MGMT###/${VLAN_MGMT}/g" \
-e "s/###CPOD###/${NAME_LOWER}/g" \
-e "s/###DOMAIN###/${ROOT_DOMAIN}/g" \
-e "s/###LIC_ESX###/${LIC_ESX}/g" \
-e "s/###LIC_VCSA###/${LIC_VCSA}/g" \
-e "s/###LIC_VSAN###/${LIC_VSAN}/g" \
-e "s/###LIC_NSXT###/${LIC_NSXT}/g" \
${SCRIPT}

echo "adding cpod key to know hosts ${CPODROUTER}."
add_cpod_ssh_key_to_edge_know_hosts "${CPODROUTER}"

echo "Adding entries into hosts of ${CPODROUTER}."
add_entry_cpodrouter_hosts "${SUBNET}.3" "cloudbuilder" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.4" "vcsa" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.5" "nsx01" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.6" "nsx01a" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.7" "nsx01b" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.8" "nsx01c" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.9" "en01" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.10" "en02" "${CPODROUTER}"
add_entry_cpodrouter_hosts "${SUBNET}.11" "sddc" "${CPODROUTER}"

echo "Enabeling dhcp on vlan ${TRANSPORTVLANID}."
enable_dhcp_cpod_vlanx 3 "${CPODROUTER}"

echo "Commiting changes on  ${CPODROUTER}."
restart_cpodrouter_dnsmasq "${CPODROUTER}"

echo "Sleeping for 10 seconds to make sure dnsmasq has been restarted"
sleep 10

echo "JSON is genereated: ${SCRIPT} and placed in directory: ${SCRIPT_DIR}."