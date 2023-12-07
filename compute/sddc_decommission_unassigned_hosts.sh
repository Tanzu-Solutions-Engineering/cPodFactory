#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_vcf_cpod> "  && echo "usage example: $0 vcf45" && exit 1

source ./extra/functions.sh

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
TOKEN=$(curl -s -k -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens | jq .accessToken | sed 's/"//g')

echo

echo "Getting list of unassigned hosts"
VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
UNASSIGNEDHOSTS=$(echo "${VALIDATIONRESULT}" | jq -r '.elements[].fqdn')

HOSTSSCRIPT=/tmp/scripts/cloudbuilder-hosts-${NAME_LOWER}.json

UNASSIGNEDHOSTSCOUNT=$(echo "${UNASSIGNEDHOSTS}" |wc -l )
if [[ $UNASSIGNEDHOSTSCOUNT -gt 0 ]]
then
	echo "$UNASSIGNEDHOSTSCOUNT hosts to decommission"
else
	echo "hostcount <=0 : $UNASSIGNEDHOSTSCOUNT"
	echo "bailing out"
	exit
fi

echo "[" > ${HOSTSSCRIPT}
for ESX in ${UNASSIGNEDHOSTS}; do
	echo "adding Host $ESX to list"
	echo '{ "fqdn" : "'"${ESX}"'" }' >> ${HOSTSSCRIPT}
	if [ ${UNASSIGNEDHOSTSCOUNT} -gt 1 ];then
		echo "," >> ${HOSTSSCRIPT}
		((UNASSIGNEDHOSTSCOUNT=UNASSIGNEDHOSTSCOUNT-1))
	fi
done
echo "]" >> ${HOSTSSCRIPT}

echo
echo "host json produced :"
cat "${HOSTSSCRIPT}" | jq . 
exit 

echo
echo "Submitting host decommissioning"
echo
COMMISIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X DELETE  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
COMMISSIONID=$(echo "${COMMISIONJSON}" | jq -r '.id' )
echo
echo "Commissioning ID : ${COMMISSIONID}"

echo
echo "Querying commisioning result"

get_commission_status(){

	COMMISSIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${COMMISSIONID})
	echo "${COMMISSIONRESULT}" > /tmp/scripts/commissionresult.json
	echo "${COMMISSIONRESULT}"
}

####

echo "Getting list of unassigned hosts"
VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
echo "${VALIDATIONRESULT}" | jq '.elements[].fqdn'

echo "Done."

