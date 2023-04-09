#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <name_of_transportzone> <name_of_logicalswitch>" && exit 1 

case $BACKEND_NETWORK in
	"NSX-V")
		TZ_ID=$( ${NETWORK_DIR}/id_transportzone.sh ${1} )
		[ "${TZ_ID}" == "" ] && echo "'${1}' doesn't exist!" && exit 1

		VIRTUALWIRE_ID=$( ${NETWORK_DIR}/props_logicialswitch.sh $1 $2 | jq '.objectId' | sed 's/"//g' )
		[ "${VIRTUALWIRE_ID}" == "" ] && echo "Logical Switch '$2' doesn't exist in '$1'." && exit 1

		echo "Deleting '${VIRTUALWIRE_ID}' on '${1}'."
		curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -H "Content-Type:text/xml;charset=UTF-8" -X DELETE https://${NSX}/api/2.0/vdn/virtualwires/${VIRTUALWIRE_ID} 2>&1 > /dev/null
		;;
	"NSX-T")
		echo "Deleting '${2}' segment."
		if [ "${NSXTVIDM}" == "YES" ]; then
			REMOTE64=$(echo -n "${NSX_ADMIN}:${NSX_PASSWD}" | base64 )
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X DELETE -H "Content-Type: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-security-profile-binding-maps/segment_security_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X DELETE -H "Content-Type: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-discovery-profile-binding-maps/segment_discovery_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X DELETE -H "Accept: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}?force=true 2>&1 > /dev/null
		else
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X DELETE -H "Content-Type: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-security-profile-binding-maps/segment_security_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X DELETE -H "Content-Type: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}/segment-discovery-profile-binding-maps/segment_discovery_binding_map_${2} 2>&1 > /dev/null
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X DELETE -H "Accept: application/json" https://${NSX}/policy/api/v1/infra/segments/${2}?force=true 2>&1 > /dev/null
		fi
		;;
esac
