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

#check if the script exists
if [ ! -f "${SCRIPT}" ]; then
  echo "Error: EMS json ${SCRIPT} does not exist"
  exit 1
fi

while [ -z "$APICHECK" ]
do  
	echo "checking if the API on cloudbuilder ${URL} is ready yet..."
	APICHECK=$(curl -s -k -u ${AUTH} -X GET ${URL}/v1/sddcs/validations)
	sleep 10
	TIMEOUT=$((TIMEOUT + 1))
	if [ $TIMEOUT -ge 48 ]; then
		echo "bailing out..."
		exit 1
	fi 
done

echo "API on cloudbuilder ${URL} is ready... thunderbirds are go!"

#validate the EMS.json
VALIDATIONID=$(curl -s -k -u ${AUTH} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST ${URL}/v1/sddcs/validations | jq '.id')

if [ -z "$VALIDATIONID" ]; then
  echo "Error: The validation ID is empty..."
  exit 1
fi

echo "The validation with id: ${VALIDATIONID} has started"

#check the validation
VALIDATIONSTATUS=$(curl -s -k -u ${AUTH} -X GET ${URL}/v1/sddcs/validations | jq -r ".elements[] | select(.id == ${VALIDATIONID}) | .resultStatus")

if [ -z "$VALIDATIONSTATUS" ]; then
  echo "Error: The validation status is empty..."
  exit 1
fi

echo "The validation with id: ${VALIDATIONID} has the status ${VALIDATIONSTATUS}"

#wait for the validation to finish
while [ ${VALIDATIONSTATUS} != "SUCCEEDED" ]
	do
	VALIDATIONSTATUS=$(curl -s -k -u ${AUTH} -X GET ${URL}/v1/sddcs/validations | jq -r ".elements[] | select(.id == ${VALIDATIONID}) | .resultStatus")
	echo "The validation with id: ${VALIDATIONID} has the status ${VALIDATIONSTATUS}..."
	sleep 10
	TIMEOUT=$((TIMEOUT + 1))
	if [ $TIMEOUT -ge 48 ]; then
		echo "bailing out..."
		exit 1
	fi
	if [ "$VALIDATIONSTATUS" == "FAILED" ]; then
		echo "bailing out..."
		exit 1
	fi
done

#proceeding with deployment
echo "Proceeding with Bringup using ${SCRIPT}."

#BRINGUPID=$(curl -s -k -u ${AUTH} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST ${URL}/v1/sddcs | jq '.id')

if [ -z "$BRINGUPID" ]; then
  echo "Error: The bringup id  is empty..."
  exit 1
fi

echo "The deployment with id: ${BRINGUPID} has started"

while [ ${BRINGUPSTATUS} != "COMPLETED_WITH_SUCCESS" ]
	do
	#check the bringup status via cURL 
	BRINGUPSTATUS=$(curl -s -k -u ${AUTH} -X GET ${URL}/v1/sddcs | jq -r ".elements[] | select(.id == ${BRINGUPID}) | .status")
	echo "The validation with id: ${BRINGUPID} has the status ${BRINGUPSTATUS}...."
	sleep 10
	TIMEOUT=$((TIMEOUT + 1))
	if [ $TIMEOUT -ge 720 ]; then
		echo "this is taking way to long bailing out..."
		exit 1 
	fi 
	if [ "$BRINGUPSTATUS" == "COMPLETED_WITH_FAILURE" ]; then
		echo "The deployment failed..."
		exit 1
	fi
done

echo "all done... do i get a cookie now?"