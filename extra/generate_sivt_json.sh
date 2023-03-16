#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

### functions ####

source ./extra/functions.sh

JSON_TEMPLATE=${JSON_SIVT_TEMPLATE:-"sivt-tkgm-template.json"}

CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )
DATACENTERNAME="cPod-${CPOD_NAME}"
# with NSX, VLAN Management is untagged
if [ ${BACKEND_NETWORK} != "VLAN" ]; then
	VLAN_MGMT="0"
fi

# test external variables

[ "${MKP_CLI_TOKEN}" == "" ] && echo "external variable ${MKP_CLI_TOKEN} not defined" && exit 1 

#VLAN01-5
if [[ ${VLAN} -gt 40 ]];then
	VLANID01="${VLAN}1"
	VLANID02="${VLAN}2"
	VLANID03="${VLAN}3"
	VLANID04="${VLAN}4"
	VLANID05="${VLAN}5"
	VLANID06="${VLAN}6"
else
	VLANID01="${VLAN}01"
	VLANID02="${VLAN}02"
	VLANID03="${VLAN}03"
	VLANID04="${VLAN}04"
	VLANID05="${VLAN}05"
	VLANID06="${VLAN}06"
fi

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 
PASSWORD64=$(echo -n ${PASSWORD} |base64 )

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/sivt-${NAME_LOWER}.json

mkdir -p ${SCRIPT_DIR} 
cp ${EXTRA_DIR}/${JSON_TEMPLATE} ${SCRIPT} 

# Generate JSON for SIVT
sed -i \
-e "s/###SUBNET###/${SUBNET}/g" \
-e "s/###PASSWORD###/${PASSWORD}/" \
-e "s/###PASSWORD64###/${PASSWORD64}/" \
-e "s/###TOKEN###/${MKP_CLI_TOKEN}/" \
-e "s/###DATACENTER###/${DATACENTERNAME}/" \
-e "s/###VLAN###/${VLAN}/g" \
-e "s/###VLAN01###/${VLANID01}/g" \
-e "s/###VLAN02###/${VLANID02}/g" \
-e "s/###VLAN03###/${VLANID03}/g" \
-e "s/###VLAN04###/${VLANID04}/g" \
-e "s/###VLAN05###/${VLANID05}/g" \
-e "s/###VLAN06###/${VLANID06}/g" \
-e "s/###VLAN_MGMT###/${VLAN_MGMT}/g" \
-e "s/###CPOD###/${NAME_LOWER}/g" \
-e "s/###DOMAIN###/${ROOT_DOMAIN}/g" \
${SCRIPT}

echo "JSON is genereated: ${SCRIPT}"
echo 
echo "sending json to sivt appliance"
echo
sshpass -p ${PASSWORD} scp -o StrictHostKeyChecking=no ~/.ssh/id_rsa.pub root@sivt.${NAME_LOWER}.${ROOT_DOMAIN}:/root/.ssh/authorized_keys
scp -o StrictHostKeyChecking=no ${SCRIPT} root@sivt.${NAME_LOWER}.${ROOT_DOMAIN}:/opt/vmware/arcas/src/vsphere-dvs-tkgm.json
echo "deploying NSX ALB and management cluster"
ssh -o StrictHostKeyChecking=no root@sivt.${NAME_LOWER}.${ROOT_DOMAIN} "arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgm.json --avi_configuration --tkg_mgmt_configuration --verbose"
echo "deploying shared service cluster"
echo "press any key to continue"
read a
ssh -o StrictHostKeyChecking=no root@sivt.${NAME_LOWER}.${ROOT_DOMAIN} "arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgm.json --shared_service_configuration  --verbose"
echo "deploying workload cluster"
echo "press any key to continue"
read a
ssh -o StrictHostKeyChecking=no root@sivt.${NAME_LOWER}.${ROOT_DOMAIN} "arcas --env vsphere --file /opt/vmware/arcas/src/vsphere-dvs-tkgm.json  --workload_preconfig --workload_deploy --verbose"

