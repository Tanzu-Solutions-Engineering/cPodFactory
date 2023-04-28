#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

source ./env

START=$( date +%s ) 

[ "$1" == "" -o "$2" == ""  ] && echo "usage: $0 <name_of_cpod> <name_of_owner>"  && echo "usage example: $0 LAB01 vedw" && exit 1


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
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
        ./extra/post_slack.sh ":wow: *${2}* you're not allowed to deploy in *${NAME_HIGHER}*"
        exit 1
fi

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

CPOD_VCSA=vcsa.${DOMAIN}
CPOD_ADMIN="administrator@${DOMAIN}"
CPOD=$( echo $1 | tr '[:upper:]' '[:lower:]' ) 
CPOD_PWD=$(cat /etc/hosts | sed -n "/cpod-${CPOD}\t/p" | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print $4}')

echo "Testing if vcsa reachable ${CPOD_VCSA} ..."
STATUS=$( ping -c 1 ${CPOD_VCSA} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "vcsa reachable."
else    
        echo "Error: can't ping vcsa."
        exit 1
fi

# generating powercli script to create template

echo
echo "========================================================"
echo "Creating new Distributed Switch for SIVT with powercli"
echo "========================================================"

PS_SCRIPT=create_vds_sivt.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

sed -i -e "s/###VCENTER###/${CPOD_VCSA}/" ${SCRIPT}
sed -i -e "s/###VCENTER_ADMIN###/${CPOD_ADMIN}/" ${SCRIPT}
sed -i -e "s/###VCENTER_PASSWD###/${CPOD_PWD}/" ${SCRIPT}
sed -i -e "s/###VLAN###/${VLAN}/" ${SCRIPT}

docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}
#rm -fr ${SCRIPT}

###################
# create DHCP segments

# add_to_cpodrouter_dnsmasq 
enable_dhcp_cpod_vlanx 2 ${CPOD_NAME_LOWER}
enable_dhcp_cpod_vlanx 6 ${CPOD_NAME_LOWER}
enable_dhcp_cpod_vlanx 7 ${CPOD_NAME_LOWER}
restart_cpodrouter_dnsmasq ${CPOD_NAME_LOWER}

#if [ ${VLAN} -gt 40 ]; then
#
#        #add dhcp segments
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}2:eth2,10.${VLAN}.2.2,10.${VLAN}.2.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}6:eth2,10.${VLAN}.6.2,10.${VLAN}.6.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}  
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}7:eth2,10.${VLAN}.7.2,10.${VLAN}.7.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}  
#else
#        #add dhcp segments
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}02:eth2,10.${VLAN}.2.2,10.${VLAN}.2.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}06:eth2,10.${VLAN}.6.2,10.${VLAN}.6.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}  
#        add_to_cpodrouter_dnsmasq "dhcp-range=eth2.${VLAN}07:eth2,10.${VLAN}.7.2,10.${VLAN}.7.254,255.255.255.0,12h" ${CPOD_NAME_LOWER}
#fi

###################

END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "====================================="
echo "=== VDSwitch creation is finished ==="
echo "=== In ${TIME} Seconds ==="
echo "====================================="
