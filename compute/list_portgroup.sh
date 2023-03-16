#!/bin/bash
#bdereims@vmware.com

. ./env

SESSION_ID=$( ${COMPUTE_DIR}/session_vcenter.sh )

curl -s --insecure -H "Accept: application/json" -H "vmware-api-session-id: ${SESSION_ID}" -X GET https://${VCENTER}/rest/vcenter/network | jq '. | .["value"] | .[] | {name: .name, network: .network}'
