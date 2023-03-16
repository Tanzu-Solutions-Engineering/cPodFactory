#!/bin/bash
#bdereims@vmware.com

. ./env

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/json" https://${NSX}/api/2.0/vdn/switches | jq ' . | .["switches"] | .[] | .["switchObj"] | .objectId' | sed 's/"//g' 
#curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/xml" https://${NSX}/api/2.0/vdn/switches/dvs-17
