#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <name_of_vcf_cpod> wldname"  && echo "usage example: $0 vcf45 wld01" && exit 1

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

WLDNAME="${2}"

SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

#USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo
echo "Getting VCF API Token"
TOKEN=$(get_sddc_token "${NAME_LOWER}" "${PASSWORD}" )

echo
echo "Listing Hosts"
SDDCHOSTS=$(get_hosts_full "${NAME_LOWER}" "${TOKEN}")

#SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq .elements[].fqdn)
echo "$SDDCHOSTS" |jq .
UNASSIGNEDID=$(echo "$SDDCHOSTS" |jq -r '.elements[]| select ( .status == "UNASSIGNED_USEABLE")| .id')
UNASSIGNEDCOUNT=$(echo "${UNASSIGNEDID}" | wc -l)

if [[ $UNASSIGNEDCOUNT -gt 0 ]]
then
	echo "$UNASSIGNEDCOUNT hosts to add"
else
	echo "hostcount <=0 : $UNASSIGNEDCOUNT"
	echo "bailing out"
	exit
fi

DOMAINJSON="${SCRIPT_DIR}/cloudbuilder-domains-$$.json"
cp "${DOMAIN_JSON_TEMPLATE}" "${DOMAINJSON}"
NEWDOMAINJSON=$(cat  "${DOMAINJSON}")

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
                    "vdsName": "###WLD_NAME###-###CLUSTERNAME###-vds-01"
                    },
                    {
                    "id": "vmnic1",
                    "uplink": "uplink2",
                    "vdsName": "###WLD_NAME###-###CLUSTERNAME###-vds-01"
                    }
                ]
                },
                "licenseKey": "###LIC_ESX###"
            }'
    
    NEWDOMAINJSON=$(echo "${NEWDOMAINJSON}" |jq '.computeSpec.clusterSpecs[].hostSpecs += ['"${HOSTJSON}"']')
done
echo "${NEWDOMAINJSON}"  >  "${DOMAINJSON}"

jq . "${DOMAINJSON}"
echo
echo "${DOMAINJSON}"

# echo "Adding host entries into hosts of ${NAME_LOWER}."
# LASTIP=$(get_last_ip  ${SUBNET}  ${NAME_LOWER})
# [[ $LASTIP -lt 50 ]] && LASTIP=50
# IPADDRESS=$((${LASTIP}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "vcsa-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01a-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01b-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01c-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "en01-"${WLDNAME} ${NAME_LOWER} 
# IPADDRESS=$((${IPADDRESS}+1))
# add_entry_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "en02-"${WLDNAME} ${NAME_LOWER} 

# restart_cpodrouter_dnsmasq ${NAME_LOWER} 

# curl -k 'https://sddc.cpod-vcf51.az-lhr.cloud-garage.net/ui/api/v1/domains' -X POST -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:120.0) Gecko/20100101 Firefox/120.0' -H 'Accept: application/json, text/plain, */*'  -H 'Accept-Language: en-US-US' -H 'Accept-Encoding: gzip, deflate, br' -H 'X-XSRF-TOKEN: tVur7sxf-XcKLodgMgZXNQSeggISbZPn0b2A' -H 'Content-Type: application/json'   -H 'Origin: https://sddc.cpod-vcf51.az-lhr.cloud-garage.net' -H 'Connection: keep-alive' -H 'Cookie: session=s%3AA9NuYKZcS5_EPx5W4fWBxUDnl4f18uKK.ecW%2FzXy9hpMXJwQNFaY6KLzhZnt4eRv3NVqEyd2LMww; XSRF-TOKEN=tVur7sxf-XcKLodgMgZXNQSeggISbZPn0b2A'    -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' 
#     --data-raw 
# '{"domainName":"wld01","orgName":"vmware","computeSpec":{"clusterSpecs":[{"name":"cl01","advancedOptions":{"highAvailability":{"enabled":true}},"datastoreSpec":{"vsanDatastoreSpec":{"licenseKey":"90084-ND24M-J88N1-09AKK-80YNN","datastoreName":"wld01-cl01-vsan01","failuresToTolerate":1,"dedupAndCompressionEnabled":false}},"networkSpec":{"nsxClusterSpec":{"nsxTClusterSpec":{"uplinkProfiles":[{"name":"wld01-cl01-vds-uplink-profile-1","teamings":[{"policy":"LOADBALANCE_SRCID","activeUplinks":["uplink-1","uplink-2"],"standByUplinks":null}],"transportVlan":1373}]}},"vdsSpecs":[{"name":"wld01-cl01-vds-01","mtu":1500,"portGroupSpecs":[{"name":"wld01-cl01-vds-01-pg-mgmt","mtu":1500,"transportType":"MANAGEMENT","activeUplinks":["uplink1","uplink2"],"standByUplinks":null,"teamingPolicy":"loadbalance_loadbased"},{"name":"wld01-cl01-vds-01-pg-vmotion","mtu":1500,"transportType":"VMOTION","activeUplinks":["uplink1","uplink2"],"standByUplinks":null,"teamingPolicy":"loadbalance_loadbased"},{"name":"wld01-cl01-vds-01-pg-vsan","mtu":1500,"transportType":"VSAN","activeUplinks":["uplink1","uplink2"],"standByUplinks":null,"teamingPolicy":"loadbalance_loadbased"}],"nsxtSwitchConfig":{"transportZones":[{"name":"overlay-tz-nsx01-wld01","transportType":"OVERLAY"}],"hostSwitchOperationalMode":"STANDARD"}}],"networkProfiles":[{"name":"networkConfigProfile","isDefault":true,"nsxtHostSwitchConfigs":[{"vdsName":"wld01-cl01-vds-01","uplinkProfileName":"wld01-cl01-vds-uplink-profile-1","vdsUplinkToNsxUplink":[{"vdsUplinkName":"uplink1","nsxUplinkName":"uplink-1"},{"vdsUplinkName":"uplink2","nsxUplinkName":"uplink-2"}]}]}]},"hostSpecs":[{"id":"cd470acc-f27f-4f99-8e43-af54f48c4b5e","hostNetworkSpec":{"vmNics":[{"id":"vmnic0","uplink":"uplink1","vdsName":"wld01-cl01-vds-01"},{"id":"vmnic1","uplink":"uplink2","vdsName":"wld01-cl01-vds-01"}]},"licenseKey":"EH09P-LEJ9J-181N1-082HH-04W1J"},{"id":"31a901a0-0150-4f94-929c-6d1d9bc0c7d6","hostNetworkSpec":{"vmNics":[{"id":"vmnic0","uplink":"uplink1","vdsName":"wld01-cl01-vds-01"},{"id":"vmnic1","uplink":"uplink2","vdsName":"wld01-cl01-vds-01"}]},"licenseKey":"EH09P-LEJ9J-181N1-082HH-04W1J"},{"id":"bfb34862-4018-483f-8836-83a1a4873383","hostNetworkSpec":{"vmNics":[{"id":"vmnic0","uplink":"uplink1","vdsName":"wld01-cl01-vds-01"},{"id":"vmnic1","uplink":"uplink2","vdsName":"wld01-cl01-vds-01"}]},"licenseKey":"EH09P-LEJ9J-181N1-082HH-04W1J"},{"id":"08263b7c-69b0-4f02-9c67-7e8687be820e","hostNetworkSpec":{"vmNics":[{"id":"vmnic0","uplink":"uplink1","vdsName":"wld01-cl01-vds-01"},{"id":"vmnic1","uplink":"uplink2","vdsName":"wld01-cl01-vds-01"}]},"licenseKey":"EH09P-LEJ9J-181N1-082HH-04W1J"}],"clusterImageId":"e86e6a24-7fca-4598-8277-77b4dc44d2ce"}]},"nsxTSpec":{"licenseKey":"WH4CM-VN152-Z8TD1-0V3KH-31W71","nsxManagerAdminPassword":"wQ1VP74R7qe!","nsxManagerAuditPassword":"wQ1VP74R7qe!","vip":"172.60.137.57","vipFqdn":"nsx01-wld01.cpod-vcf51.az-lhr.cloud-garage.net","nsxManagerSpecs":[{"name":"nsx01a-wld01","networkDetailsSpec":{"ipAddress":"172.60.137.53","dnsName":"nsx01a-wld01.cpod-vcf51.az-lhr.cloud-garage.net","gateway":"172.60.137.1","subnetMask":"255.255.255.0"}},{"name":"nsx01b-wld01","networkDetailsSpec":{"ipAddress":"172.60.137.54","dnsName":"nsx01b-wld01.cpod-vcf51.az-lhr.cloud-garage.net","gateway":"172.60.137.1","subnetMask":"255.255.255.0"}},{"name":"nsx01c-wld01","networkDetailsSpec":{"ipAddress":"172.60.137.55","dnsName":"nsx01c-wld01.cpod-vcf51.az-lhr.cloud-garage.net","gateway":"172.60.137.1","subnetMask":"255.255.255.0"}}]},"subscriptionLicense":null,"vcenterSpec":{"name":"vcsa-wld01","rootPassword":"wQ1VP74R7qe!","datacenterName":"wld01-DC","networkDetailsSpec":{"ipAddress":"172.60.137.56","dnsName":"vcsa-wld01.cpod-vcf51.az-lhr.cloud-garage.net","gateway":"172.60.137.1","subnetMask":"255.255.255.0"}}}'
