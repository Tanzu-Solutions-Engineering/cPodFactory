#!/bin/bash
#bdereims@vmware.com


[ "${1}" == "" ] && echo "usage: ${0} deploy_env vm_name" && exit 1

. ./env

if [ -f "${1}" ]; then
	. ./${COMPUTE_DIR}/"${1}"
else
	SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

	[ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

	CPOD=${1}
	. ./${COMPUTE_DIR}/cpod-xxx_env
fi

###################

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool vi://${ADMIN}:'${PASSWORD}'@vcsa.${DOMAIN}/cPod-${CPOD}/vm/${2} ${BITS}/${2}.ova
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
