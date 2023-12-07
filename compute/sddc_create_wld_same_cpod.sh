#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <name_of_vcf_cpod> wldname"  && echo "usage example: $0 vcf45 wld01" && exit 1

source ./extra/functions.sh

NEWHOSTS_JSON_TEMPLATE=cloudbuilder-hosts.json

#Management Domain CPOD
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )

WLDNAME="${2}"

SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

#USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo
echo "Getting VCF API Token"
TOKEN=$(curl -s -k -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens | jq .accessToken | sed 's/"//g')

echo
echo "Listing Hosts"
SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq .elements[].fqdn)
echo "$SDDCHOSTS" |jq .


echo "Adding host entries into hosts of ${NAME_LOWER}."
LASTIP=$(get_last_ip  ${SUBNET}  ${NAME_LOWER})
[[ $LASTIP -lt 50 ]] && LASTIP=50
IPADDRESS=$((${LASTIP}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "vcsa-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01a-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01b-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01c-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${LASTIP}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "en01-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "en02-"${WLDNAME} ${NAME_LOWER} 

restart_cpodrouter_dnsmasq ${NAME_LOWER} 
