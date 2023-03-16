#!/bin/bash
#bdereims@vmware.com


[ "${1}" == "" ] && echo "usage: ${0} deploy_env" && exit 1

. ./env

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

HOSTNAME=${HOSTNAME_VIC}
NAME=${NAME_VIC}
IP=${IP_VIC}
OVA=${OVA_VIC}

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig \
--prop:appliance.root_pwd=${PASSWORD} \
--prop:appliance.permit_root_login=True \
--prop:network.ip0=${IP} \
--prop:network.netmask0=${NETMASK} \
--prop:network.gateway=${GATEWAY} \
--prop:network.DNS=${DNS} \
--prop:network.searchpath=${DOMAIN} \
--prop:network.fqdn=${HOSTNAME}.${DOMAIN} \
--prop:registry.deploy=True \
--prop:registry.port=443 \
--prop:registry.notary_port=4443 \
--prop:registry.admin_password=${PASSWORD} \
--prop:registry.db_password=${PASSWORD} \
--prop:registry.gc_enabled=False \
--prop:management_portal.deploy=True \
--prop:management_portal.port=8282 \
--prop:fileserver.port=9443 \
--prop:engine_installer.port=1337 \
--prop:cluster_manager.deploy=True \
--prop:cluster_manager.port=5683 \
--prop:cluster_manager.admin=admin \
-ds=${DATASTORE} -n=${NAME} --network='${PORTGROUP}' \
${OVA} \
vi://${ADMIN}:'${VC_PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
