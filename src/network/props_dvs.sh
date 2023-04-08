#!/bin/bash
#bdereims@vmware.com

. ./src/env

[ "$1" == "" ] && echo "usage: $0 <dvs_id>" && exit 1

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/xml" https://${NSX}/api/2.0/vdn/switches/${1}
