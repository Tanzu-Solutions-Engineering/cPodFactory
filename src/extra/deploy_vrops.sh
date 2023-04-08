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

HOSTNAME=${HOSTNAME_VROPS}
NAME=${NAME_VROPS}
IP=${IP_VROPS}
OVA=${OVA_VROPS}

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig \
"--prop:vamitimezone=Europe/Paris" \
--prop:vami.DNS.vRealize_Operations_Manager_Appliance=${DNS} \
--prop:vami.gateway.vRealize_Operations_Manager_Appliance=${GATEWAY} \
--prop:vami.ip0.vRealize_Operations_Manager_Appliance=${IP} \
--prop:vami.netmask0.vRealize_Operations_Manager_Appliance=${NETMASK} \
-ds=${DATASTORE} -n=${NAME} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
