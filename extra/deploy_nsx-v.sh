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

HOSTNAME=${HOSTNAME_NSX}
NAME=${NAME_NSX}
IP=${IP_NSX}
OVA=${OVA_NSX}

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
ovftool --acceptAllEulas --skipManifestCheck --X:injectOvfEnv --allowExtraConfig \
--prop:vsm_cli_passwd_0=${PASSWORD} \
--prop:vsm_cli_en_passwd_0=${PASSWORD} \
--prop:vsm_hostname=${HOSTNAME} \
--prop:vsm_ip_0=${IP} \
--prop:vsm_netmask_0=${NETMASK} \
--prop:vsm_gateway_0=${GATEWAY} \
--prop:vsm_dns1_0=${DNS} \
--prop:vsm_domain_0=${DOMAIN} \
--prop:vsm_ntp_0=${NTP} \
--prop:vsm_isSSHEnabled=True \
-ds=${DATASTORE} -n=${NAME} --network='${PORTGROUP}' \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
