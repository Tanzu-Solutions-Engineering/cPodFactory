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

HOSTNAME=${HOSTNAME_HCI}
NAME=${NAME_HCI}
OVA=${OVA_HCI}

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --allowExtraConfig \
--X:apiVersion=5.5 --diskMode=thin \
--prop:Public_Network_Type=DHCP \
--prop:System_Password="${PASSWORD}" \
"--datastore=${DATASTORE}" -n=${NAME} \
--net:"Management Network"="${PORTGROUP}" --net:"VM Network"="${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
