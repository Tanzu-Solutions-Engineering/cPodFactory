#!/bin/bash
#bdereims@vmware.com


[ "${1}" == "" ] && echo "usage: ${0} vm_name" && exit 1

. ./env

### Local vars ####

TARGET="${VCENTER}/${VCENTER_DATACENTER}"
ADMIN="administrator%40vsphere.local"
PASSWORD="${VCENTER_PASSWD}"

###

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool \
vi://${ADMIN}:${PASSWORD}@${TARGET}/vm/${1} /data/BITS/${1}.ova
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
