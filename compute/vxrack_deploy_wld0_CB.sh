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

echo ""
echo "Hit enter or ctrl-c to launch prereqs validation:"
read answer
curl -i -k -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations
echo ""
echo ""
echo "Check prereqs in CloudBuilder:"
echo "check url : https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}"
echo "using pwd : ${PASSWORD}"
echo 
echo "when validation confirmed,"
echo "Hit enter or ctrl-c to launch deployment:"
read answer
curl -i -k -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -d @${SCRIPT} -X POST https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs
echo ""
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

#curl -k -u admin:"YDAboI6FLcp!" -X GET https://cloudbuilder.cpod-bygel.az-lhr.cloud-garage.net/v1/sddcs/validations | jq '.elements[] | select(.id == "845c240f-dbe4-45ca-b022-1a4f24570ceb") | .resultStatus'
