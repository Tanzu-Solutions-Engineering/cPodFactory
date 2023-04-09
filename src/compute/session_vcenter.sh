#!/bin/bash
#bdereims@vmware.com

. ./env

curl -s --insecure -X POST --header "Content-Type: application/json" --header "vmware-use-header-authn: JSON" --header "vmware-api-session-id: null" -u ${VCENTER_ADMIN}:${VCENTER_PASSWD} https://${VCENTER}/rest/com/vmware/cis/session | jq '.value' | sed 's/"//g'
