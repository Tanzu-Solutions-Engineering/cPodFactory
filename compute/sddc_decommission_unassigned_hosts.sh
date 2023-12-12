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

echo
echo "Getting VCF API Token"
TOKEN=$(get_sddc_token "${NAME_LOWER}" "${PASSWORD}" )

echo
echo "Getting list of unassigned hosts"
# VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
# UNASSIGNEDHOSTS=$(echo "${VALIDATIONRESULT}" | jq -r '.elements[].fqdn')
UNASSIGNEDHOSTS=$(get_hosts_unassigned "${NAME_LOWER}" "${TOKEN}")

HOSTSSCRIPT=/tmp/scripts/cloudbuilder-hosts-${NAME_LOWER}.json

UNASSIGNEDHOSTSCOUNT=$(echo -n "${UNASSIGNEDHOSTS}" |wc -l )
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

echo
echo "Submitting host decommissioning"
echo
COMMISIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X DELETE  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
COMMISSIONID=$(echo "${COMMISIONJSON}" | jq -r '.id' )
echo
echo "Commissioning ID : ${COMMISSIONID}"

echo
echo "Querying commisioning result"

echo
echo "Querying commisioning result"
echo
loop_wait_commissioning  "${COMMISSIONID}"


# RESPONSE=$(get_commission_status "${COMMISSIONID}")
# if [[ "${RESPONSE}" == *"ERROR"* ]] || [[ "${RESPONSE}" == "" ]]
# then
# 	echo
# 	echo "problem getting initial commissioning ${COMMISSIONID} status : "
# 	echo "${RESPONSE}"
# 	exit
# else
# 	STATUS=$(echo "${RESPONSE}" | jq -r '.status')
# 	echo "${STATUS}"
# fi

# CURRENTSTATE=${STATUS}
# CURRENTSTEP=""
# CURRENTMAINTASK=""
# while [[ "${STATUS}" != "Successful" ]]
# do      
# 	RESPONSE=$(get_commission_status "${COMMISSIONID}")
# 	#echo "${RESPONSE}" |jq .
# 	if [[ "${RESPONSE}" == *"ERROR"* ]] || [[ "${RESPONSE}" == "" ]]
# 	then
# 		echo "problem getting deployment ${COMMISSIONID} status : "
# 		echo "${RESPONSE}"		
# 	else
# 		STATUS=$(echo "${RESPONSE}" | jq -r '.status')
# 		MAINTASK=$(echo "${RESPONSE}" | jq -r '.subTasks[] | select ( .status | contains("IN_PROGRESS")) |.description')
# 		SUBTASK=$(echo "${RESPONSE}" | jq -r '.subTasks[] | select ( .status | contains("IN_PROGRESS")) |.name')

# 		if [[ "${MAINTASK}" != "${CURRENTMAINTASK}" ]] 
# 		then
# 			printf "\t%s" "${MAINTASK}"
# 			CURRENTMAINTASK="${MAINTASK}"
# 		fi	
# 		if [[ "${SUBTASK}" != "${CURRENTSTEP}" ]] 
# 		then
# 			if [ "${CURRENTSTEP}" != ""  ]
# 			then
# 				FINALSTATUS=$(echo "${RESPONSE}" | jq -r '.subTasks[]| select ( .name == "'"${CURRENTSTEP}"'") |.status')
# 				printf "\t%s" "${FINALSTATUS}"
# 			fi
# 			printf "\n\t\t%s" "${SUBTASK}"
# 			CURRENTSTEP="${SUBTASK}"
# 		fi
# 	fi
# 	if [[ "${STATUS}" == "FAILED" ]] 
# 	then 
# 		echo
# 		echo "FAILED"
# 		echo "${RESPONSE}" | jq .
# 		echo "stopping script"
# 		exit 1
# 	fi
# 	printf '.' >/dev/tty
# 	sleep 2
# done
# RESPONSE=$(get_commission_status "${COMMISSIONID}")
# RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.status')

# echo
# echo "Host Commisioning Result Status : $RESULTSTATUS"

####

echo "Getting list of unassigned hosts"
UNASSIGNEDHOSTS=$(get_hosts_unassigned "${NAME_LOWER}" "${TOKEN}")
echo "${UNASSIGNEDHOSTS}" 

echo "Done."

