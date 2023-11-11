#!/bin/bash
#bdereims@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

source ./env
source ./extra/functions.sh

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

#add_entry_cpodrouter_hosts() {
#	echo "add ${1} -> ${2}"
#	ssh -o LogLevel=error ${NAME_LOWER} "sed "/${1}/d" -i /etc/hosts ; printf \"${1}\\t${2}\\n\" >> /etc/hosts"
#}

JSON_TEMPLATE=${JSON_TEMPLATE:-"cloudbuilder-43.json"}
DNSMASQ_TEMPLATE=dnsmasq.conf-vcf
BGPD_TEMPLATE=bgpd.conf-vcf

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

if [ ${VLAN} -gt 40 ]; then
	VMOTIONVLANID=${VLAN}1
	VSANVLANID=${VLAN}2
	TRANSPORTVLANID=${VLAN}3
else
	VMOTIONVLANID=${VLAN}01
	VSANVLANID=${VLAN}02
	TRANSPORTVLANID=${VLAN}03
fi

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/cloudbuilder-${NAME_LOWER}.json
DNSMASQ=/tmp/scripts/dnsmasq-${NAME_LOWER}.conf
BGPD=/tmp/scripts/bgpd-${NAME_LOWER}.conf


echo
echo "Generating cloudbuilder jsons"

mkdir -p ${SCRIPT_DIR} 
cp ${COMPUTE_DIR}/${JSON_TEMPLATE} ${SCRIPT} 
cp ${COMPUTE_DIR}/${DNSMASQ_TEMPLATE} ${DNSMASQ} 
cp ${COMPUTE_DIR}/${BGPD_TEMPLATE} ${BGPD} 

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

# Generate DNSMASQ conf file
sed -i -e "s/###SUBNET###/${SUBNET}/g" \
-e "s/###PASSWORD###/${PASSWORD}/" \
-e "s/###VLAN###/${VLAN}/g" \
-e "s/###VLANID###/${TRANSPORTVLANID}/g" \
-e "s/###CPOD###/${NAME_LOWER}/g" \
-e "s/###DOMAIN###/${ROOT_DOMAIN}/g" \
-e "s/###ROOT_DOMAIN###/${ROOT_DOMAIN}/g" \
-e "s/###TRANSIT_GW###/${TRANSIT_GW}/g" \
${DNSMASQ}

# Generate BGPD conf file
sed -i -e "s/###VLAN###/${VLAN}/g" \
-e "s/###ASN###/${ASN}/g" \
-e "s/###HEADER_ASN###/${HEADER_ASN}/g" \
-e "s/###TRANSIT_GW###/${TRANSIT_GW}/g" \
-e "s/###TRANSIT_NET###/${TRANSIT_NET}/g" \
${BGPD}

#add_cpodrouter_bgp_neighbor 

echo "Modifying dnsmasq on cpodrouter."
scp ${DNSMASQ} ${NAME_LOWER}:/etc/dnsmasq.conf

echo "Modifying bgpd on cpodrouter."
#scp ${BGPD} ${NAME_LOWER}:/etc/quagga/bgpd.conf

echo "Adding entries into hosts of ${NAME_LOWER}."
add_entry_cpodrouter_hosts "${SUBNET}.3" "cloudbuilder"  ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.4" "vcsa" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.5" "nsx01" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.6" "nsx01a" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.7" "nsx01b" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.8" "nsx01c" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.9" "en01" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.10" "en02" ${NAME_LOWER}
add_entry_cpodrouter_hosts "${SUBNET}.11" "sddc" ${NAME_LOWER}

restart_cpodrouter_dnsmasq ${NAME_LOWER}  

echo "JSON is genereated: ${SCRIPT}"
echo

#read -n1 -s -r -p $'Hit enter to launch prereqs validation or ctrl-c to stop.\n' key
echo "CheckingCloudbuilder is ready"

get_cloudbuilder_status() {
        #returns json
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        case $HTTPSTATUS in

                200)    
                        echo "READY"
                        ;;

                503)    
                        echo "Not Ready"
                        ;;
                *)      
                         echo ${RESPONSE} |awk -F '####' '{print $1}'
                        ;;

        esac
}

echo "  Checking cloudbuilder status"
echo
printf "\t connecting to cloudbuilder ."
INPROGRESS=$(get_cloudbuilder_status)
CURRENTSTATE=${INPROGRESS}
while [[ "$INPROGRESS" != "READY" ]]
do      
		printf '.' >/dev/tty
		sleep 10
		INPROGRESS=$(get_cloudbuilder_status)
		if [ "${INPROGRESS}" != "${CURRENTSTATE}" ] 
		then 
				printf "\n\t%s" ${INPROGRESS}
				CURRENTSTATE=${INPROGRESS}
		fi
done

echo
echo "Submitting SDDC validation"
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ] || [ $HTTPSTATUS -eq 202 ] 
then
    VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
	echo "${VALIDATIONJSON}" > /tmp/scripts/validation_request.json
	VALIDATIONID=$(echo ${VALIDATIONJSON} | jq -r .id )
	echo "	validation id : ${VALIDATIONID}"
else
        echo "  error initiating validation"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

get_validation_status() {
	#returns json
	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations/${VALIDATIONID})
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		200)    
			VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
			EXECUTIONSTATUS=$(echo ${VALIDATIONJSON} | jq -r .executionStatus)
			echo "${EXECUTIONSTATUS}"
			;;
		503)    
			echo "Not Ready"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

echo
echo "Querying validation result"

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations/${VALIDATIONID})
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
case $HTTPSTATUS in
	200)    
		VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
		STATUS=$(echo ${VALIDATIONJSON} | jq -r .executionStatus)
		echo "${STATUS}"
		;;
	503)    
		echo "Not Ready"
		;;
	*)      
		echo ${RESPONSE} |awk -F '####' '{print $1}'
		;;
esac

CURRENTSTATE=${STATUS}
CURRENTSTEP=""
while [[ "$STATUS" != "COMPLETED" ]]
do      
	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations/${VALIDATIONID})
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		200)    
			VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
			STATUS=$(echo ${VALIDATIONJSON} | jq -r .executionStatus)
			INPROGRESS=$(echo "${VALIDATIONJSON}" | jq '.validationChecks[] | select ( .resultStatus == "IN_PROGRESS") |.description')
			if [ "${INPROGRESS}" != "${CURRENTSTEP}" ] 
			then
				FINALSTATUS=$(echo "${VALIDATIONJSON}" | jq '.validationChecks[]| select ( .description == '"${INPROGRESS}"') |.description  ')
				printf "\t%s" "${FINALSTATUS}"
				printf "\n\t%s" "${INPROGRESS}"
				CURRENTSTEP="${INPROGRESS}"
			fi
			;;
		503)    
			echo "Not Ready"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
	if [ "${STATUS}" == "FAILED" ] 
	then 
		echo
		echo "FAILED"
		echo ${VALIDATIONRESULT} | jq .
		echo "stopping script"
		exit 1
	fi
	printf '.' >/dev/tty
	sleep 2
done


echo 
echo "Validation completed"
echo

##############
read -n1 -s -r -p $'Hit enter to launch deployment or ctrl-c to stop.\n' key

#curl -i -k -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
		DEPLOYMENTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
		echo "${DEPLOYMENTINFO} created succesfully"
		DEPLOYMENTID=$(echo "${DEPLOYMENTINFO}" |jq '.id')
else
		echo "  error creating deployment : ${DEPLOYMENTINFO}"
		echo ${HTTPSTATUS}
		echo ${RESPONSE}
		exit
fi

get_deployment_status() {
	#returns json
	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/${DEPLOYMENTID})
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		200)    
			VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
			EXECUTIONSTATUS=$(echo ${VALIDATIONJSON} | jq -r .status)
			echo "${EXECUTIONSTATUS}"
			;;
		503)    
			echo "Not Ready"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

echo
printf "\t Querying deployment status ."
INPROGRESS=$(get_deployment_status)
CURRENTSTATE=${INPROGRESS}
while [[ "$INPROGRESS" != "COMPLETED" ]]
do      
		printf '.' >/dev/tty
		sleep 10
		INPROGRESS=$(get_deployment_status)
		if [ "${INPROGRESS}" != "${CURRENTSTATE}" ] 
		then 
				printf "\n\t%s" ${INPROGRESS}
				CURRENTSTATE=${INPROGRESS}
		fi
		if [ "${INPROGRESS}" == "FAILED" ] 
		then 
			echo
			echo "FAILED"
			echo ${VALIDATIONRESULT} | jq .
			echo "stopping script"
			exit 1
		fi
done



# govc guest.run -vm /intel-DC/vm/cPod-VCF51-MGMT-cloudbuilder -l root:GcPr59hhCno! cat /etc/hostname


echo
echo "Check deployment in CloudBuilder:"
echo "check url : https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}"
echo "using pwd : ${PASSWORD}"
echo
echo "when deployment finished, please manually edit sddc properties as follows:"
echo "ssh vcf@sddc.${NAME_LOWER}.${ROOT_DOMAIN}"
echo "su -"
echo "pwd = ${PASSWORD}"
echo 'DOMAINMGR=$(find /etc -name application-pro* | grep domainmanager)'
echo 'echo "nsxt.manager.formfactor=small" >> $DOMAINMGR'
echo 'echo "nsxt.management.resources.validation.skip=true" >> $DOMAINMGR'
echo 'echo "vc.deployment.option=management-tiny" >> $DOMAINMGR'

echo "verify the 2 lines have been added as expected"
echo 'cat $DOMAINMGR'
echo "restart service :"
echo "systemctl restart domainmanager"
echo "exit"
echo "exit"


# Delete a failed deployment
# curl -X GET http://localhost:9080/bringup-app/bringup/sddcs/test/deleteAll
