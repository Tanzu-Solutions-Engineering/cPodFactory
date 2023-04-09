#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_transportzone>" && exit 1 

case $BACKEND_NETWORK in
	"NSX-V")
		TZ_ID=$( ${NETWORK_DIR}/id_transportzone.sh ${1} )
		[ "${TZ_ID}" == "" ] && echo "${1} doesn't exist!" && exit 1
		curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" "https://${NSX}/api/2.0/vdn/scopes/${TZ_ID}/virtualwires?pagesize=254&startindex=0" | jq '. | .["dataPage"] | .["data"] | .[] | {name: .name, vdnID: .vdnId, portgroup: .backing[].backingValue}' 
		;;
	"NSX-T")
		if [ "${NSXTVIDM}" == "YES" ]; then
			REMOTE64=$(echo -n "${NSX_ADMIN}:${NSX_PASSWD}" | base64 )
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X GET -H "Accept: application/json" https://${NSX}/policy/api/v1/infra/segments
			#| jq '. | .["results"] | .[] | select(._create_user ==
			#"'${NSX_ADMIN}'") | {name: .display_name, id: .id, nested_esx: .nested_nsx}'
		else
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/policy/api/v1/infra/segments
			#| jq '. | .["results"] | .[] | select(._create_user ==
			#"'${NSX_ADMIN}'") | {name: .display_name, id: .id, nested_esx: .nested_nsx}'		
		fi
		;;

esac
