#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <id_of_edge> <bgp_conf_xml>" && exit 1 

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -X PUT -H "Content-Type:text/xml;charset=UTF-8" -d @${2} https://${NSX}/api/4.0/edges/${1}/routing/config
