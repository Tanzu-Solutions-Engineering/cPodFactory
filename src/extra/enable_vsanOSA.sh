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


###################

# generating powercli script to create template

echo
echo "=================================="
echo "Enabling DRS/VSAN/HA with powercli"
echo "=================================="

PS_SCRIPT=enable_vsanOSA.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

sed -i -e "s/###VCENTER###/${CPOD_VCSA}/" ${SCRIPT}
sed -i -e "s/###VCENTER_ADMIN###/${CPOD_ADMIN}/" ${SCRIPT}
sed -i -e "s/###VCENTER_PASSWD###/${CPOD_PWD}/" ${SCRIPT}

docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}
#rm -fr ${SCRIPT}

END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "========================================="
echo "=== VSAN enabling is finished ==="
echo "=== In ${TIME} Seconds ==="
echo "========================================="
