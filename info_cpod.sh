#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>"  && echo "usage example: $0 LAB01" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1
        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### functions ####

source ./extra/functions.sh

### Local vars ####

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

CPOD_VCSA=vcsa.${DOMAIN}
CPOD=$( echo $1 | tr '[:upper:]' '[:lower:]' ) 
PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${NAME_HIGHER} ) 

CPODS=$(cat /etc/hosts |grep cpod- | wc -l)

echo =====================
echo "${CPOD_NAME} informations" 
echo =====================
echo "Network information:"
echo
CPODROUTERIP=$(ssh ${CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)
echo "cpodrouter - VM Network : ${CPODROUTERIP}"
echo "     |"
ssh ${CPOD_NAME} "ip add | grep inet | grep eth2"  |sed "s/eth2.//" | awk '{print "     |____VLAN: " $5 " - gateway : " $2}'
echo 
echo "dns server : ${CPODROUTERIP}"
echo "search domain : ${DOMAIN}" 
echo "ntp server : ${CPODROUTERIP}"
echo =====================
echo "DHCP entries"
echo
ssh  ${CPOD_NAME} "cat /etc/dnsmasq.conf" |grep -e range -e option
echo =====================
echo "DNS entries"
ssh  ${CPOD_NAME} "cat /etc/hosts" |grep -v  -e "#" -e ":" -e "127.0.0.1" | sort -t . -k 2,2n -k 3,3n -k 4,4n
echo =====================
echo "connect to cpod vcsa"
echo
echo " url: https://${CPOD_VCSA}/ui"
echo " user : administrator@${DOMAIN}"
echo " pwd : ${PASSWORD}"
echo =====================
