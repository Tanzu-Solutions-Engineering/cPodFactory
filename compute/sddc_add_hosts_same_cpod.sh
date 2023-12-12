#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_vcf_cpod> "  && echo "usage example: $0 vcf45" && exit 1

source ./extra/functions.sh
source ./extra/functions_sddc_mgr.sh
NEWHOSTS_JSON_TEMPLATE=cloudbuilder-hosts.json

#Management Domain CPOD
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )

SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

#USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo
echo "Getting VCF API Token"
TOKEN=$(get_sddc_token "${NAME_LOWER}" "${PASSWORD}" )

echo
echo "Listing Hosts"
SDDCHOSTS=$(get_hosts_fqdn "${NAME_LOWER}" "${TOKEN}")
echo "${SDDCHOSTS}"

echo
echo "Listing Network Pools"
get_network_pools "${NAME_LOWER}" "${TOKEN}"

#SDDCNETPOOLS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq '.elements[] | {id, name}')
#echo "$SDDCNETPOOLS"
echo
echo "id of MGMT NP POOL"
WLDNPPOOLID=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq -r '.elements[] | select(.name == "np01") | .id' )
echo "$WLDNPPOOLID"

NPPOOLNAME="np01"
# get wld esx hosts

CPODHOSTS=$(ssh -o LogLevel=error ${NAME_LOWER}  "cat /etc/hosts | cut -f2 | grep esx")
#echo $WLDHOSTS

HOSTSSCRIPT=/tmp/scripts/cloudbuilder-hosts-${NAME_LOWER}.json

CPODHOSTCOUNT=$(echo "${CPODHOSTS}" |wc -l )
SDDCHOSTCOUNT=$(echo "${SDDCHOSTS}" |wc -l )
HOSTCOUNT=$((CPODHOSTCOUNT-SDDCHOSTCOUNT))
if [[ $HOSTCOUNT -gt 0 ]]
then
	echo "$HOSTCOUNT hosts to add"
else
	echo "hostcount <=0 : $HOSTCOUNT"
	echo "bailing out"
	exit
fi

echo "[" > ${HOSTSSCRIPT}
for ESX in ${CPODHOSTS}; do
	#echo ${ESX}
	#echo ${HOSTCOUNT}
	if [ "$(echo "$SDDCHOSTS" |grep $ESX)" == "" ]
	then 
		echo "adding Host $ESX to list"
		cat ${COMPUTE_DIR}/${NEWHOSTS_JSON_TEMPLATE} >> ${HOSTSSCRIPT}
		
		ESX_FQDN="${ESX}.${NAME_LOWER}.${ROOT_DOMAIN}"
		sed -i -e "s/###ESXFQDN###/${ESX_FQDN}/g" \
		-e "s/###POOLID###/${WLDNPPOOLID}/g" \
		-e "s/###NPPOOL###/${NPPOOLNAME}/g" \
		-e "s/###PASSWORD###/${PASSWORD}/g" \
		${HOSTSSCRIPT}
		if [ ${HOSTCOUNT} -gt 1 ];then
			echo "," >> ${HOSTSSCRIPT}
			((HOSTCOUNT=HOSTCOUNT-1))
		fi
	else
		echo "Host $ESX already known by SDDC"
	fi
done
echo "]" >> ${HOSTSSCRIPT}

# echo
# echo "host json produced :"
# cat "${HOSTSSCRIPT}" | jq . 

echo
echo "Submitting host validation"
VALIDATIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations)
VALIDATIONID=$(echo "${VALIDATIONJSON}" | jq -r '.id')
#echo ${VALIDATIONID}

echo "Querying validation result"
echo
loop_wait_hosts_validation "${VALIDATIONID}"

####

echo
echo "Submitting host commisioning"
COMMISIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
COMMISSIONID=$(echo "${COMMISIONJSON}" | jq -r '.id' )
echo
echo "Commissioning ID : ${COMMISSIONID}"

echo
echo "Querying commisioning result"
echo
loop_wait_commissioning  "${COMMISSIONID}"

####

echo "Getting list of unassigned hosts"
UNASSIGNEDHOSTS=$(get_hosts_unassigned "${NAME_LOWER}" "${TOKEN}")
echo "${UNASSIGNEDHOSTS}" 

echo "Done."