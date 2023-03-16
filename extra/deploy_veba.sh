#!/bin/bash
#bdereims@vmware.com


[ "${1}" == "" ] && echo "usage: ${0} deploy_env" && exit 1

. ./env

[ "${1}" == "" ] && echo "usage: ${0}  <deploy_env or cPod Name> <path to OVA>" && exit 1

if [ -f "${1}" ]; then
	. ./${COMPUTE_DIR}/"${1}"
else
	SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

	[ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

	CPOD=${1}
	. ./${COMPUTE_DIR}/cpod-xxx_env
fi

### functions ####

source ./extra/functions.sh

### Local vars ####

HOSTNAME="veba"
NAME="veba"
OVA="${3}"
IP=${SUBNET}.99
PODCIDR="10.255.0.0/16"

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
        exit 1
fi

echo "Testing if something is already on the same @IP..."
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        exit 1
fi
echo "It seems ok, let's deploy ova."

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
export LANG=en_US.UTF-8
cd /root/cPodFactory/ovftool
./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --powerOn  --sourceType=OVA  \
--X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
--name=${NAME} --datastore=${VCENTER_DATASTORE} --noSSLVerify \
--diskMode=thin \
--net:"VM Network"="${PORTGROUP}" \
--prop:guestinfo.hostname=${HOSTNAME}.${DOMAIN} \
--prop:guestinfo.ipaddress=${IP} \
--prop:guestinfo.netmask="24 (255.255.255.0)" \
--prop:guestinfo.gateway=${GATEWAY} \
--prop:guestinfo.dns=${DNS} \
--prop:guestinfo.domain=${DOMAIN} \
--prop:guestinfo.ntp=${GATEWAY} \
--prop:guestinfo.root_password='${PASSWORD}' \
--prop:guestinfo.enable_ssh=True \
--prop:guestinfo.vcenter_server=${TARGET} \
--prop:guestinfo.vcenter_username=${ADMIN} \
--prop:guestinfo.vcenter_password='${PASSWORD}' \
--prop:guestinfo.vcenter_veba_ui_username="veba-user" \
--prop:guestinfo.vcenter_veba_ui_password='${PASSWORD}' \
--prop:guestinfo.vcenter_disable_tls_verification=True \
--prop:guestinfo.webhook=True \
--prop:guestinfo.webhook_username="webhook-user" \
--prop:guestinfo.webhook_password='${PASSWORD}' \
--prop:guestinfo.debug=True \
--prop:guestinfo.pod_network_cidr="${PODCIDR}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

echo "script: "${MYSCRIPT}
echo 
sh ${MYSCRIPT}

echo "Adding entries into hosts of ${CPOD_NAME_LOWER}."
add_to_cpodrouter_hosts "${IP}" "${NAME}"  ${CPOD_NAME_LOWER}


# to review later
#TODO reminder to do something
#FIXME
#--prop:guestinfo.http_proxy= \
#--prop:guestinfo.https_proxy= \
#--prop:guestinfo.proxy_username= \
#--prop:guestinfo.proxy_password= \
#--prop:guestinfo.no_proxy= \

#--prop:guestinfo.horizon= \
#--prop:guestinfo.horizon_server= \
#--prop:guestinfo.horizon_domain= \
#--prop:guestinfo.horizon_username= \
#--prop:guestinfo.horizon_password= \
#--prop:guestinfo.horizon_disable_tls_verification= \

#--prop:guestinfo.custom_tls_private_key= \
#--prop:guestinfo.custom_tls_ca_cert= \
#
#--prop:guestinfo.syslog_server_hostname= \
#--prop:guestinfo.syslog_server_port= \
#--prop:guestinfo.syslog_server_protocol= \
#--prop:guestinfo.syslog_server_format= \