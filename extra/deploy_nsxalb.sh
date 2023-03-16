#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

if [ -z "$LOGGING" ]
then
    echo "enabling logging"
    export LOGGING="TRUE"
    /usr/bin/script /tmp/scripts/nsxalb-$$-log.txt /bin/bash -c "$0 $*"
    exit 0
fi

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

[ "${HOSTNAME_NSXALB}" == ""  -o "${NSXALBOVA}" == "" -o "${IP_NSXALBMGR}" == "" ] && echo "missing parameters - please source version file !" && exit 1

### functions ####

add_to_cpodrouter_hosts() {
	echo "add ${1} -> ${2}"
	ssh -o LogLevel=error ${CPOD_NAME_LOWER} "sed "/${1}/d" -i /etc/hosts ; printf \"${1}\\t${2}\\n\" >> /etc/hosts"
	ssh -o LogLevel=error ${CPOD_NAME_LOWER} "systemctl restart dnsmasq.service"
}

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

if [[ -z "${NSXALBOVA}" ]]; then
        echo "NSXALBOVA not set"
        echo "please source correct version file first"
        exit 1
fi


#this is required because files will be mounted from local path to container volume
shortIsoFileName=$(echo ${NSXALBOVA} | sed 's/.*\///')
ovafilewithpath="/tmp/BITS/${shortIsoFileName}"


###################

# generating powercli script to create template

echo
echo "=========================================="
echo "Deploying NSX ALB controller with powercli"
echo "=========================================="

PS_SCRIPT=deploy_nsxalb.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

sed -i -e "s/###VCENTER###/${CPOD_VCSA}/" ${SCRIPT}
sed -i -e "s/###VCENTER_ADMIN###/${CPOD_ADMIN}/" ${SCRIPT}
sed -i -e "s/###VCENTER_PASSWD###/${CPOD_PWD}/" ${SCRIPT}
sed -i -e "s/###VLAN###/${VLAN}/" ${SCRIPT}
sed -i -e "s=###ALB-OVA###=${ovafilewithpath}=" ${SCRIPT}
sed -i -e "s/###DATACENTER###/${NAME_HIGHER}/" ${SCRIPT}
sed -i -e "s/###DOMAIN###/${DOMAIN}/" ${SCRIPT}


docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts -v /data/BITS:/tmp/BITS vmware/powerclicore:12.4 ${SCRIPT}
#rm -fr ${SCRIPT}



echo "Adding entries into hosts of ${NAME_LOWER}."
add_to_cpodrouter_hosts "10.${VLAN}.1.10" "nsxalb01"


END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "==================================="
echo "=== NSX ALB Deployment finished ==="
echo "=== In ${TIME} Seconds ==="
echo "==================================="

export LOGGING=""