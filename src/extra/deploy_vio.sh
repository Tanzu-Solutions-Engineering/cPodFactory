#!/bin/bash
#bdereims@vmware.com

[ "${1}" == "" ] && echo "usage: ${0} deploy_env" && exit 1

. ./src/env

[ "${1}" == "" ] && echo "usage: ${0} <deploy_env or cPod Name>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### Local vars ####

HOSTNAME=${HOSTNAME_VIO}
NAME=${NAME_VIO}
IP=${IP_VIO}
OVA=${OVA_VIO}
VC_PASSWORD=$( ./extra/passwd_for_cpod.sh ${1} )
PASSWORD=${VC_PASSWORD}

###################

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
ovftool --acceptAllEulas --allowExtraConfig \
--prop:vami.domain.management-server=${DOMAIN} \
--prop:vami.ip0.management-server=${IP} \
--prop:vami.netmask0.management-server=${NETMASK} \
--prop:vami.gateway.management-server=${GATEWAY} \
--prop:vami.DNS.management-server=${DNS} \
--prop:vami.searchpath.management-server=${DOMAIN} \
--prop:ntpServer=${NTP} \
--prop:syslogServer=vrli.${DOMAIN} \
--prop:syslogProtocol=UDP \
--prop:syslogPort=514 \
"--prop:viouser_passwd=${PASSWD}" \
--vService:"installation"="com.vmware.vim.vsm:extension_vservice" \
-ds=${DATASTORE} -n=${NAME} --network='${PORTGROUP}' \
${OVA} \
vi://${ADMIN}:'${VC_PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
