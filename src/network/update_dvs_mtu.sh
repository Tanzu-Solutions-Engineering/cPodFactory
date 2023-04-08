#!/bin/bash
#bdereims@vmware.com

. ./src/env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <vds_id> <mtu_size>" && exit 1 


UPDATE=$( ./network/props_dvs.sh ${1} | tail -1 | sed "s#<mtu>.*</mtu>#<mtu>${2}</mtu>#" )
VDS_ID=$( echo $UPDATE | sed -e "s#</objectId>.*##" -e "s#^.*>##" )

curl -s -k -u ${NSX_ADMIN}:${NSX_PASSWD} -H "Content-Type:text/xml;charset=UTF-8" -X PUT --data "${UPDATE}" https://${NSX}/api/2.0/vdn/switches
