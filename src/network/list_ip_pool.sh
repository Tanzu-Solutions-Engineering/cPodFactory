#!/bin/bash
#bdereims@vmware.com

. ./src/env

#curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/2.0/services/ipam/pools/scope/globalroot-0 | jq '. | .["allScopes"] | .[0] | {name: .name, id: .id}'
curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/2.0/services/ipam/pools/${1}/ipaddresses | jq
