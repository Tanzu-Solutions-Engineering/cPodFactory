#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name> <owner email>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
	. ./${EXTRA_DIR}/functions.sh
fi

### Local vars ####

HOSTNAME=${HOSTNAME_CLOUDBUILDER}
NAME=${NAME_CLOUDBUILDER}
IP=${IP_CLOUDBUILDER}
OVA=${OVA_CLOUDBUILDER}

###################

TEMP=/tmp/$$

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
        exit 1
fi

echo "Testing if something is already on the same @IP..."
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        exit 1
fi
echo "It seems ok, let's deploy cloudbuilder ova."

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

if [ "${CLOUDBUILDER_PLACEMENT}" == "ATSIDE" ]; then

	VAPP="cPod-${NAME_HIGHER}"
	NAME="${VAPP}-${HOSTNAME_CLOUDBUILDER}"
	DATASTORE=${VCENTER_DATASTORE}

	case "${BACKEND_NETWORK}" in
		NSX-V)
			PORTGROUP=$( ${NETWORK_DIR}/list_logicalswitch.sh ${NSX_TRANSPORTZONE} | jq 'select(.name == "'${CPOD_NAME_LOWER}'") | .portgroup' | sed 's/"//g' )
			CPOD_PORTGROUP=$( ${COMPUTE_DIR}/list_portgroup.sh | jq 'select(.network == "'${PORTGROUP}'") | .name' | sed 's/"//g' )
			;;
		NSX-T)
			CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
                        ;;
		VLAN)
			CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
			;;
	esac

	govc import.spec ${OVA_CLOUDBUILDER} > ${TEMP}

	cat ${TEMP} | jq '.IPAllocationPolicy="fixedPolicy"' > ${TEMP}-tmp
        cp ${TEMP}-tmp ${TEMP} ; rm ${TEMP}-tmp
	
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.ADMIN_PASSWORD" "Value" "${PASSWORD}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.ROOT_PASSWORD" "Value" "${PASSWORD}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.hostname" "Value" "${HOSTNAME}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.ip0" "Value" "${IP}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.netmask0" "Value" "${NETMASK}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.gateway" "Value" "${GATEWAY}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.DNS" "Value" "${DNS}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.domain" "Value" "${DOMAIN}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.searchpath" "Value" "${DOMAIN}"
	replace_json ${TEMP} "PropertyMapping" "Key" "guestinfo.ntp" "Value" "${GATEWAY}"
	replace_json ${TEMP} "NetworkMapping" "Name" "Network 1" "Network" "${CPOD_PORTGROUP}"

	export GOVC_NETWORK="${CPOD_PORTGROUP}"
	export GOVC_RESOURCE_POOL="/${GOVC_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}"

	govc import.ova -options=${TEMP} -name="${NAME}" ${OVA}
	govc vm.power -on ${NAME}

else

	echo "rien!"

fi

rm ${TEMP}