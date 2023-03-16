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

HOSTNAME=${HOSTNAME_RIFT}
NAME=${NAME_RIFT}
OVA=${OVA_RIFT}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

ADMIN="administrator@vsphere.local"
TARGET="vcsa.${DOMAIN}/dc01/host/cl01"
PORTGROUP="Dummy"

export MYSCRIPT=/tmp/$$

if [ "${JUMPBOX_PLACEMENT}" == "ATSIDE" ]; then

        VAPP="cPod-${NAME_HIGHER}"
        NAME="${VAPP}-${HOSTNAME}"
        DATASTORE=${VCENTER_DATASTORE}

        case "${BACKEND_NETWORK}" in
                NSX-V)
                        PORTGROUP=$( ${NETWORK_DIR}/list_logicalswitch.sh ${NSX_TRANSPORTZONE} | jq 'select(.name == "'${CPOD_NAME_LOWER}'") | .portgroup' | sed 's/"//g' )
                        CPOD_PORTGROUP=$( ${COMPUTE_DIR}/list_portgroup.sh | jq 'select(.network == "'${PORTGROUP}'") | .name' | sed 's/"//g' )
                        ;;
                VLAN)
                        CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
                        ;;
        esac

	cat << EOF > ${MYSCRIPT}
	cd ${OVFDIR}
	ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
	--X:injectOvfEnv --overwrite --powerOffTarget --allowExtraConfig \
	--X:apiVersion=5.5 --diskMode=thin \
	"--datastore=${DATASTORE}" -n=${NAME} -nw="${CPOD_PORTGROUP}" \
	${OVA} \
	vi://${VCENTER_ADMIN}:${VCENTER_PASSWD}@${VCENTER}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}
EOF

else
        cat << EOF > ${MYSCRIPT}
        cd ${OVFDIR}
        ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
        --X:injectOvfEnv --overwrite --powerOffTarget --allowExtraConfig \
        --X:apiVersion=5.5 --diskMode=thin \
        "--datastore=${DATASTORE}" -n=${NAME} -nw="${PORTGROUP}" \
        ${OVA} \
        vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

fi

sh ${MYSCRIPT}

rm ${MYSCRIPT}
