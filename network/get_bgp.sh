#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <id_of_edge>" && exit 1 

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X GET -H "Accept: application/xml" https://${NSX}/api/4.0/edges/${1}/routing/config/bgp
