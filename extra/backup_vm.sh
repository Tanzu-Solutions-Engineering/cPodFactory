#!/bin/bash
#bdereims@vmware.com


[ "${2}" == "" ] && echo "usage: ${0} <cpod_name> <vm_name>" && exit 1

. ./env

if [ -f "${1}" ]; then
	. ./${COMPUTE_DIR}/"${1}"
else
	SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

	[ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

	CPOD=${1}
	. ./${COMPUTE_DIR}/cpod-xxx_env
fi

### Local vars ####

###################


PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )
MYTARGET=$( echo ${TARGET} | sed -e "s/cPod-STRCH\/host\/Cluster//g" )

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool vi://${ADMIN}:'${PASSWORD}'@${MYTARGET}/cPod-${1}/vm/${2} /data/BITS/${1}-${2}.ova
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
