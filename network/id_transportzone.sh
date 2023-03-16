#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_transportzone>" && exit 1 

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/2.0/vdn/scopes | jq '. | .["allScopes"] | .[0] | select(.name == "'${1}'") | .id' | sed 's/"//g' 

case $BACKEND_NETWORK in
	"NSX-V")
		curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/2.0/vdn/scopes | jq '. | .["allScopes"] | .[0] | select(.name == "'${1}'") | .id' | sed 's/"//g' 
		;;
	"NSX-T")
		if [ "${NSXTVIDM}" == "YES" ]; then
			REMOTE64=$(echo -n "${NSX_ADMIN}:${NSX_PASSWD}" | base64 )
			curl -s -k -H "Authorization: Remote ${REMOTE64}" -X GET -H "Accept: application/json" https://${NSX}/api/v1/transport-zones/ | jq '. | .["results"] | .[] | select(.display_name == "'${1}'") | .id' | sed -e "s/\"//g"			#| jq '. | .["results"] | .[] | select(._create_user ==
			#"'${NSX_ADMIN}'") | {name: .display_name, id: .id, nested_esx: .nested_nsx}'
		else
			curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/v1/transport-zones/ | jq '. | .["results"] | .[] | select(.display_name == "'${1}'") | .id' | sed -e "s/\"//g"
			#| jq '. | .["results"] | .[] | select(._create_user ==
			#"'${NSX_ADMIN}'") | {name: .display_name, id: .id, nested_esx: .nested_nsx}'		
		fi
		;;
esac
