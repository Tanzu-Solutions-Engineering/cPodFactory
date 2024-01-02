#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] || [ "$2" == "" ] || [ "$3" == "" ] && echo "usage: $0 <name_of_vcf_cpod> wldname clustername"  && echo "usage example: $0 vcf45 wld01 cl01" && exit 1

source ./extra/functions.sh

source ./extra/functions_sddc_mgr.sh

NEWHOSTS_JSON_TEMPLATE=cloudbuilder-hosts.json
DOMAIN_JSON_TEMPLATE=./compute/cloudbuilder-domains-v5.json

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

if [ ${VLAN} -gt 40 ]; then
	VMOTIONVLANID=${VLAN}1
	VSANVLANID=${VLAN}2
	TRANSPORTVLANID=${VLAN}3
else
	VMOTIONVLANID=${VLAN}01
	VSANVLANID=${VLAN}02
	TRANSPORTVLANID=${VLAN}03
fi


WLDNAME="${2}"
CLUSTERNAME="${3}"


SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

# Check WLD exists in DNS entries

DNSCOUNT=$(ssh -o LogLevel=error -o StrictHostKeyChecking=no "${NAME_LOWER}" "cat /etc/hosts" |grep -c "${WLDNAME}")
if [[ $DNSCOUNT -gt 0 ]]
then
	echo "$DNSCOUNT dns entries found for ${WLDNAME}"
	echo "bailing out"
	exit
else
	echo "no dns entries found for ${WLDNAME} - proceeding"
fi

#USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo
echo "Getting VCF API Token"
TOKEN=$(get_sddc_token "${NAME_LOWER}" "${PASSWORD}" )

echo
echo "Listing Unassigned Hosts IDs"
SDDCHOSTS=$(get_hosts_full "${NAME_LOWER}" "${TOKEN}")
UNASSIGNEDID=$(echo "$SDDCHOSTS" |jq -r '.elements[]| select ( .status == "UNASSIGNED_USEABLE")| .id')
echo "$UNASSIGNEDID"
UNASSIGNEDCOUNT=$(echo "${UNASSIGNEDID}" | wc -l)

if [[ $UNASSIGNEDCOUNT -gt 0 ]]
then
	echo "$UNASSIGNEDCOUNT hosts to add"
else
	echo "hostcount <=0 : $UNASSIGNEDCOUNT"
	echo "bailing out"
	exit

fi

LICENSEKEYS=$(get_license_keys_full "${NAME_LOWER}" "${TOKEN}")
ESXLICENSE=$(echo "${LICENSEKEYS}" |jq -r '.elements[] | select (.productType == "ESXI" )| .key')
VSANLICENSE=$(echo "${LICENSEKEYS}" |jq -r '.elements[] | select (.productType == "VSAN" )| .key')
NSXLICENSE=$(echo "${LICENSEKEYS}" |jq -r '.elements[] | select (.productType == "NSXT" )| .key')
VCENTERLICENSE=$(echo "${LICENSEKEYS}" |jq -r '.elements[] | select (.productType == "VCENTER" )| .key')

DOMAINJSON="${SCRIPT_DIR}/cloudbuilder-domains-$$.json"
cp "${DOMAIN_JSON_TEMPLATE}" "${DOMAINJSON}"

#check and generate IPs
echo "Adding host entries into hosts of ${NAME_LOWER}."
LASTIP=$(get_last_ip  ${SUBNET}  ${NAME_LOWER})
[[ $LASTIP -lt 50 ]] && LASTIP=50
IPADDRESS=$((${LASTIP}+1))
VCENTERIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${VCENTERIP}" "vcsa-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
NSXTVIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${NSXTVIP}" "nsx01-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
NSX01AIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${NSX01AIP}" "nsx01a-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
NSX01BIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${NSX01BIP}" "nsx01b-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
NSX01CIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${NSX01CIP}" "nsx01c-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
EN01VIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${EN01VIP}" "en01-"${WLDNAME} ${NAME_LOWER} 
IPADDRESS=$((IPADDRESS+1))
EN02VIP="${SUBNET}.${IPADDRESS}"
add_entry_cpodrouter_hosts "${EN02VIP}" "en02-"${WLDNAME} ${NAME_LOWER} 

restart_cpodrouter_dnsmasq ${NAME_LOWER} 

#Replace Values
sed -i -e "s/###WLD_NAME###/${WLDNAME}/g" \
		-e "s/###CLUSTERNAME###/${CLUSTERNAME}/g" \
        -e "s/###CPOD###/${NAME_LOWER}/g" \
        -e "s/###DOMAIN###/${ROOT_DOMAIN}/g" \
		-e "s/###LIC_VSAN###/${VSANLICENSE}/g" \
        -e "s/###LIC_NSXT###/${NSXLICENSE}/g" \
		-e "s/###PASSWORD###/${PASSWORD}/g" \
        -e "s/###SUBNET###/${SUBNET}/g" \
        -e "s/###NSXTVIP###/${NSXTVIP}/g" \
        -e "s/###NSX01AIP###/${NSX01AIP}/g" \
        -e "s/###NSX01BIP###/${NSX01BIP}/g" \
        -e "s/###NSX01CIP###/${NSX01CIP}/g" \
        -e "s/###VCENTERIP###/${VCENTERIP}/g" \
		${DOMAINJSON}

cp "${DOMAINJSON}" "${SCRIPT_DIR}/cloudbuilder-domains-sed.json"

NEWDOMAINJSON=$(cat  "${DOMAINJSON}")

NEWDOMAINJSON=$(echo "${NEWDOMAINJSON}" |jq '.computeSpec.clusterSpecs[].networkSpec.nsxClusterSpec.nsxTClusterSpec.uplinkProfiles[].transportVlan = '"${TRANSPORTVLANID}"'')

CLUSTERIMAGEID=$(get_personalities_full "${NAME_LOWER}" "${TOKEN}" |jq -r .elements[].personalityId)
NEWDOMAINJSON=$(echo "${NEWDOMAINJSON}" |jq '.computeSpec.clusterSpecs[].clusterImageId = "'"${CLUSTERIMAGEID}"'"')

for HOSTID in ${UNASSIGNEDID}; do
    echo $HOSTID

    HOSTJSON='
    {
                "id": "'"${HOSTID}"'",
                "hostNetworkSpec": {
                "vmNics": [
                    {
                    "id": "vmnic0",
                    "uplink": "uplink1",
                    "vdsName": "'"${WLDNAME}-${CLUSTERNAME}"'-vds-01"
                    },
                    {
                    "id": "vmnic1",
                    "uplink": "uplink2",
                    "vdsName": "'"${WLDNAME}-${CLUSTERNAME}"'-vds-01"
                    }
                ]
                },
                "licenseKey": "'"${ESXLICENSE}"'"
            }'
    
    echo "${HOSTJSON}" |jq . 

    NEWDOMAINJSON=$(echo "${NEWDOMAINJSON}" |jq '.computeSpec.clusterSpecs[].hostSpecs += ['"${HOSTJSON}"']')
done
echo "creating domain json file : ${DOMAINJSON}"
echo "${NEWDOMAINJSON}"  >  "${DOMAINJSON}"

echo
echo "${DOMAINJSON}"

echo
echo "Submitting domain validation"
echo
VALIDATIONSTATUS=$(post_domain_validation "${NAME_LOWER}" "${TOKEN}" "${DOMAINJSON}" )
echo "${VALIDATIONSTATUS}"
echo
RESULT=$(echo "${VALIDATIONSTATUS}" |jq -r '.resultStatus')

if [ "${RESULT}" != "SUCCEEDED" ]
then
    echo "domain spec validation error - bailing out"
    exit
fi

echo
echo "Submitting domain creation"

echo
CREATIONSTATUS=$(post_domain_creation "${NAME_LOWER}" "${TOKEN}" "${DOMAINJSON}" )
echo "${CREATIONSTATUS}"
echo
CREATIONID=$(echo "${CREATIONSTATUS}" |jq -r '.id')

echo
loop_wait_commissioning  "${CREATIONID}"
