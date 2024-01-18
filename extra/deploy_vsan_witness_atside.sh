#!/bin/bash
#edewitte@vmware.com

source ./env 
source ./govc_env
source ./extra/functions.sh

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

### Local vars ####

HOSTNAME=vsanwitness
FQDN=${HOSTNAME}.${DOMAIN}
IPLASTBIT=199
WITNESSOVA=""

OVFFILE=$(ls ${BITSDIR}/VMware-VirtualSAN-Witness-*)
OVFTST=$(echo "${OVFFILE}" |wc -l)
if [ "${OVFTST}" -gt 1 ]
then
    echo "Select OVA"
    select OVF in ${OVFFILE}; do 
        if [ "${OVF}" = "Quit" ]; then 
            break
        fi
        echo
        echo "you selected ova : ${OVF}"
            WITNESSOVA=${OVF}
        break
    done
else
    WITNESSOVA=${OVFFILE}
    echo
    echo "using ova : ${WITNESSOVA}"
fi

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
#        ./extra/post_slack.sh ":wow: *${2}* you're not allowed to deploy in *${NAME_HIGHER}*"
        exit 1
fi
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"

SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
IP=${SUBNET}.${IPLASTBIT}

VMNAME="${VAPP}-${HOSTNAME}"
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        exit 1
fi

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
export LANG=en_US.UTF-8
cd /root/cPodFactory/ovftool
./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --powerOn  --sourceType=OVA  \
--X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
--name=${VMNAME} --datastore=${VCENTER_DATASTORE} --noSSLVerify \
--diskMode=thin \
--net:"Management Network"="${CPOD_PORTGROUP}" \
--net:"Secondary Network"="${CPOD_PORTGROUP}" \
--prop:"guestinfo.passwd"="${PASSWORD}" \
--prop:"guestinfo.vsannetwork"="Management" \
--prop:"guestinfo.ipaddress0"="${IP}" \
--prop:"guestinfo.netmask0"=255.255.255.0 \
--prop:"guestinfo.gateway0"=${GATEWAY} \
--prop:"guestinfo.dnsDomain"="${DOMAIN}" \
--prop:"guestinfo.hostname"="${HOSTNAME}.${DOMAIN}" \
--prop:"guestinfo.dns"=${GATEWAY} \
--prop:"guestinfo.ntp"=${GATEWAY} \
${WITNESSOVA} \
'vi://${VCENTER_ADMIN}:${VCENTER_PASSWD}@${VCENTER}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}'
EOF

sh ${MYSCRIPT}

echo "Adding entries into hosts of ${CPOD_NAME_LOWER}."

add_to_cpodrouter_hosts "${IP}" "${HOSTNAME}" "${CPOD_NAME_LOWER}"
restart_cpodrouter_dnsmasq "${CPOD_NAME_LOWER}"

#rm ${MYSCRIPT}
