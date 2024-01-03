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

# Check SDDC Mgr is ready"
check_sddc_ready  "${NAME_LOWER}" "${PASSWORD}"

# Check SDDC lab settings"
echo
echo "prepping SDDC Manager"
#wait for ESXCLI to become available 
while [ "$SSHOK" != 0 ]
do  
	SSHOK=$( sshpass -p "${PASSWORD}" ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "UserKnownHostsFile=/dev/null" -o "LogLevel=error" vcf@sddc.${NAME_LOWER}.${ROOT_DOMAIN} exit >/dev/null 2>&1; echo $? ) 
	echo "SSH status ===$SSHOK==="
	sleep 2
	TIMEOUT=$((TIMEOUT + 1))
	if [ $TIMEOUT -ge 10 ]; then
		echo "bailing out..."
		exit 1  
	fi 
done
echo "scp script"
sshpass -p "${PASSWORD}" scp  -o "StrictHostKeyChecking=no" -o "UserKnownHostsFile=/dev/null" ./compute/sddc_manager_lab_settings.sh vcf@sddc.${NAME_LOWER}.${ROOT_DOMAIN}:/home/vcf

export GOVC_USERNAME="administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
export GOVC_PASSWORD="${PASSWORD}"
export GOVC_URL="https://vcsa.${NAME_LOWER}.${ROOT_DOMAIN}"
export GOVC_INSECURE=1
export GOVC_DATACENTER=""

SDDCVM=$(govc find -type m |grep -i sddc)
echo "execute script"
govc guest.run -vm "${SDDCVM}" -l root:"${PASSWORD}" sh /home/vcf/sddc_manager_lab_settings.sh

# Check SDDC Mgr is ready"
check_sddc_ready  "${NAME_LOWER}" "${PASSWORD}"

echo 
echo "SDDC Manager configuration completed"
echo
