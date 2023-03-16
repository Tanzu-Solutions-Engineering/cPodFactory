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

### Local vars ####

HOSTNAME=${HOSTNAME_TKGIMC}
NAME=${NAME_TKGIMC}
IP=${IP_TKGIMC}
OVA=${OVA_TKGIMC}

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

STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
#        ./extra/post_slack.sh ":wow: Are you sure that VCSA is not already deployed in ${1}. Something have the same @IP."
        exit 1
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
export LANG=en_US.UTF-8
cd /root/cPodFactory/ovftool
./ovftool --acceptAllEulas --X:injectOvfEnv --powerOn  --sourceType=OVA  \
--X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
--name=${NAME} --datastore=${DATASTORE} --noSSLVerify \
--diskMode=thin --net:"VM Network"="VM Network" \
--prop:appliance.root_pwd=${PASSWORD} \
--prop:appliance.permit_root_login=True \
--prop:network.ip0=${IP} \
--prop:network.netmask0=255.255.255.0 \
--prop:network.gateway=${GATEWAY} \
--prop:network.DNS=${GATEWAY} \
--prop:network.searchpath=${DOMAIN} \
--prop:network.fqdn=${HOSTNAME}.${DOMAIN} \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

#rm ${MYSCRIPT}
