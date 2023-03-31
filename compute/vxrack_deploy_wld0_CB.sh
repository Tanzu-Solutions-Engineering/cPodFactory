#!/bin/bash
#goldyck@vmware.com

# $1 : cPod Name
# This scrips deploys a VCF management domain using an already deployed cloudbuilder.

# source helper functions
. ./env
source ./extra/functions.sh

#input validation check
if [ $# -ne 1 ]; then
  echo "usage: $0 <name_of_cpod>"
  echo "usage example: $0 LAB01 4 vedw" 
  exit
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
TIMEOUT=0

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

#make the curl more readable
URL="https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}"
AUTH="admin:${PASSWORD}"

#validate the EMS.json
VALIDATIONID=$(curl -k -u ${AUTH} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST ${URL}/v1/sddcs/validations | jq '.id')
echo "The validation with id: ${VALIDATIONID} has started"

#check the validation
VALIDATIONSTATUS=$(curl -k -u ${AUTH} -X GET ${URL}/v1/sddcs/validations | jq ".elements[] | select(.id == ${VALIDATIONID}) | .resultStatus")
echo "The validation with id: ${VALIDATIONID} has the status ${VALIDATIONSTATUS}"

  #wait for the validation to finish
  while [ "$VALIDATIONSTATUS" != "SUCCESS" ]
  do  
	VALIDATIONSTATUS=$(curl -k -u ${AUTH} -X GET ${URL}/v1/sddcs/validations | jq ".elements[] | select(.id == ${VALIDATIONID}) | .resultStatus")
	echo "The validation with id: ${VALIDATIONID} has the status ${VALIDATIONSTATUS}"
    sleep 10
    TIMEOUT=$((TIMEOUT + 1))
    if [ $TIMEOUT -ge 24 ]; then
    	echo "bailing out..."
    	exit 1  
    fi 
	if [ "$VALIDATIONSTATUS" == "FAILED" ]; then
		echo "bailing out..."
		exit 1
	fi  
  done
echo "Great Success!!!"
