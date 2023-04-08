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

HOSTNAME=${HOSTNAME_VRLI}
NAME=${NAME_VRLI}
IP=${IP_VRLI}
OVA=${OVA_VRLI}

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig \
--prop:vami.DNS.VMware_vCenter_Log_Insight=${DNS} \
--prop:vami.domain.VMware_vCenter_Log_Insight=${DOMAIN} \
--prop:vami.gateway.VMware_vCenter_Log_Insight=${GATEWAY} \
--prop:vami.hostname.VMware_vCenter_Log_Insight=${HOSTNAME} \
--prop:vami.ip0.VMware_vCenter_Log_Insight=${IP} \
--prop:vami.netmask0.VMware_vCenter_Log_Insight=${NETMASK} \
--prop:vami.searchpath.VMware_vCenter_Log_Insight=${DOMAIN} \
--prop:vm.rootpw=${PASSWORD} \
-ds=${DATASTORE} -n=${NAME} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
