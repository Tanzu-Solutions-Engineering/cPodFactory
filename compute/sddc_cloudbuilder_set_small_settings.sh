#!/bin/bash
#bdereims@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

source ./env
source ./extra/functions_sddc_mgr.sh
source ./govc_env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>" && exit 1 

# ========= CODE ===========
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

SCRIPT_DIR=/tmp/scripts

mkdir -p ${SCRIPT_DIR} 

# Check cloudbuilder is ready"
check_cloudbuilder_ready  "${NAME_LOWER}" "${PASSWORD}"

# Check cloudbuilder lab settings"
echo
echo "prepping cloudbuilder"
#wait for ESXCLI to become available 
while [ "$SSHOK" != 0 ]
do  
	SSHOK=$( sshpass -p "${PASSWORD}" ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "UserKnownHostsFile=/dev/null" -o "LogLevel=error" admin@cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN} exit >/dev/null 2>&1; echo $? ) 
	echo "SSH status ===$SSHOK==="
	sleep 2
	TIMEOUT=$((TIMEOUT + 1))
	if [ $TIMEOUT -ge 10 ]; then
		echo "bailing out..."
		exit 1  
	fi 
done
echo "scp script"
sshpass -p "${PASSWORD}" scp  -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" ./compute/cloudbuilder_lab_settings.sh admin@sddc.${NAME_LOWER}.${ROOT_DOMAIN}:/home/admin
BUILDERVM=$(govc ls vm | grep -i ${NAME_LOWER} | grep cloudbuilder)
echo "execute script"
govc guest.run -vm "${BUILDERVM}" -l root:"${PASSWORD}" sh /home/admin/cloudbuilder_lab_settings.sh

# Check cloudbuilder is ready"
check_cloudbuilder_ready  "${NAME_LOWER}" "${PASSWORD}"

echo 
echo "Cloudbuilder configuration completed"
echo
