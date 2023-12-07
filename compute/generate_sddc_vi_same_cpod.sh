#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" -o "$2" == ""  ] && echo "usage: $0 <name_of_vcf_cpod> <name_of_wld_cpod>"  && echo "usage example: $0 vcf45 vcf45-wld01" && exit 1

source ./extra/functions.sh

NP_JSON_TEMPLATE=cloudbuilder-networkpool.json
NEWHOSTS_JSON_TEMPLATE=cloudbuilder-hosts.json

#Management Domain CPOD
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )

# with NSX, VLAN Management is untagged
if [ ${BACKEND_NETWORK} != "VLAN" ]; then
	VLAN_MGMT="0"
fi

if [ ${WLDVLAN} -gt 40 ]; then
	VMOTIONVLANID=${WLDVLAN}1
	VSANVLANID=${WLDVLAN}2
	VLANID=${WLDVLAN}3
else
	VMOTIONVLANID=${WLDVLAN}01
	VSANVLANID=${WLDVLAN}02
	VLANID=${WLDVLAN}03
fi

SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

#USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo "Getting VCF API Token"
TOKEN=$(curl -s -k -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens | jq .accessToken | sed 's/"//g')

echo "Listing Hosts"
SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq .elements[].fqdn)
echo $SDDCHOSTS

echo
echo "Listing Network Pools"
SDDCNETPOOLS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq '.elements[] | {id, name}')
echo $SDDCNETPOOLS
echo "id of MGMT NP POOL"
WLDNPPOOLID=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq '.elements[] | select(.name == "np01") | .id' | sed 's/"//g')
echo $WLDNPPOOLID

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
	if [ $(echo "$SDDCHOSTS" |grep $ESX) == "" ]
	then 
		echo "adding Host $ESX to list"
		cat ${COMPUTE_DIR}/${NEWHOSTS_JSON_TEMPLATE} >> ${HOSTSSCRIPT}
		
		ESX_FQDN="${ESX}.${WLDNAME_LOWER}.${ROOT_DOMAIN}"
		sed -i -e "s/###ESXFQDN###/${ESX_FQDN}/g" \
		-e "s/###POOLID###/${WLDNPPOOLID}/g" \
		-e "s/###NPPOOL###/${NPPOOLNAME}/g" \
		-e "s/###PASSWORD###/${PASSWORD}/g" \
		${HOSTSSCRIPT}
		if [ ${HOSTCOUNT} -gt 1 ];then
			echo "," >> ${HOSTSSCRIPT}
		fi
	else
		echo "Host $ESX already known by SDDC"
	fi
	((HOSTCOUNT=HOSTCOUNT-1))
done
echo "]" >> ${HOSTSSCRIPT}

echo "host json produced :"
cat ${HOSTSSCRIPT} | jq . 

echo "Submitting host validation"
VALIDATIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations)
VALIDATIONID=$(echo ${VALIDATIONJSON} | jq .id | sed 's/"//g')
#echo ${VALIDATIONID}

echo "Querying validation result"
VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations/${VALIDATIONID})
EXECUTIONSTATUS=$(echo ${VALIDATIONRESULT} | jq .executionStatus | sed 's/"//g')

while [[ "${EXECUTIONSTATUS}" != "COMPLETED" ]]
do
	case  ${EXECUTIONSTATUS} in 
		IN_PROGRESS)
			echo "IN_PROGRESS"
			;;
		FAILED)
			echo "FAILED"
			echo ${VALIDATIONRESULT} | jq .
			echo "stopping script"
			exit 1
			;;
		*)
			echo ${EXECUTIONSTATUS}
			;;
	esac
	sleep 10
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations/${VALIDATIONID})
	EXECUTIONSTATUS=$(echo ${VALIDATIONRESULT} | jq .executionStatus | sed 's/"//g')
done

echo "Submitting host commisioning"
COMMISIONJSON=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${HOSTSSCRIPT} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
VALIDATIONID=$(echo ${COMMISIONJSON} | jq .id | sed 's/"//g')
echo ${VALIDATIONID}

echo "Querying commisioning result"
VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${VALIDATIONID})
EXECUTIONSTATUS=$(echo ${VALIDATIONRESULT} | jq .status | sed 's/"//g')

while [[ "${EXECUTIONSTATUS}" != "Successful" ]]
do
	case  ${EXECUTIONSTATUS} in 
		"In Progress")
			echo "In Progress"
			;;
		FAILED)
			echo "FAILED"
			echo ${VALIDATIONRESULT} | jq .
			echo "stopping script"
			exit 1
			;;
		*)
			echo ${EXECUTIONSTATUS}
			;;
	esac
	sleep 30
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${VALIDATIONID})
	echo ${VALIDATIONRESULT} | jq .
	EXECUTIONSTATUS=$(echo ${VALIDATIONRESULT} | jq .status | sed 's/"//g')
done
echo "Host commisionned"
echo "Getting list of unassigned hosts"
VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
echo ${VALIDATIONRESULT} | jq .

exit

echo "Adding host entries into hosts of ${NAME_LOWER}."
LASTIP=$(get_last_ip  ${SUBNET}  ${NAME_LOWER})
IPADDRESS=$((${LASTIP}+1))
add_to_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "vcsa-"${WLDCPOD_NAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_to_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01-"${WLDCPOD_NAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_to_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01a-"${WLDCPOD_NAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_to_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01b-"${WLDCPOD_NAME} ${NAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_to_cpodrouter_hosts "${SUBNET}.${IPADDRESS}" "nsx01c-"${WLDCPOD_NAME} ${NAME_LOWER} 

echo "Adding host entries into hosts of ${WLDNAME_LOWER}."
LASTIP=$(get_last_ip  ${WLDSUBNET}  ${WLDNAME_LOWER})
IPADDRESS=$((${LASTIP}+1))
add_to_cpodrouter_hosts "${WLDSUBNET}.${IPADDRESS}" "en01-"${WLDCPOD_NAME} ${WLDNAME_LOWER} 
IPADDRESS=$((${IPADDRESS}+1))
add_to_cpodrouter_hosts "${WLDSUBNET}.${IPADDRESS}" "en02-"${WLDCPOD_NAME} ${WLDNAME_LOWER} 


