#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name> <owner email>" && exit 1

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

HOSTNAME=${HOSTNAME_CLOUDBUILDER}
NAME=${NAME_CLOUDBUILDER}
IP=${IP_CLOUDBUILDER}
OVA=${OVA_CLOUDBUILDER}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
        exit 1
fi

VAPP="cPod-${NAME_HIGHER}"
NAME="${VAPP}-${HOSTNAME_CLOUDBUILDER}"
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"

echo "Testing if something is already on the same @IP..."
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        exit 1
fi
echo "It seems ok, let's deploy cloudbuilder ova."

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
export LANG=en_US.UTF-8
cd /root/cPodFactory/ovftool
./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --powerOn  --sourceType=OVA  \
--X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
--name=${NAME} --datastore=${VCENTER_DATASTORE} --noSSLVerify \
--diskMode=thin \
--net:"Network 1"="${CPOD_PORTGROUP}" \
--prop:"FIPS_ENABLE"= \
--prop:"guestinfo.ADMIN_USERNAME"=admin \
--prop:"guestinfo.ADMIN_PASSWORD"="${PASSWORD}" \
--prop:"guestinfo.ROOT_PASSWORD"="${PASSWORD}" \
--prop:"guestinfo.hostname"=${HOSTNAME}.${DOMAIN} \
--prop:"guestinfo.ip0"=${IP} \
--prop:"guestinfo.netmask0"=255.255.255.0 \
--prop:"guestinfo.gateway"=${GATEWAY} \
--prop:"guestinfo.DNS"=${DNS} \
--prop:"guestinfo.domain"=${DOMAIN} \
--prop:"guestinfo.searchpath"=${DOMAIN} \
--prop:"guestinfo.ntp"=${GATEWAY} \
${OVA} \
'vi://${VCENTER_ADMIN}:${VCENTER_PASSWD}@${VCENTER}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}'
EOF

sh ${MYSCRIPT}

echo "Adding entries into hosts of ${CPOD_NAME_LOWER}."
add_to_cpodrouter_hosts ${IP} ${HOSTNAME} ${CPOD_NAME_LOWER}