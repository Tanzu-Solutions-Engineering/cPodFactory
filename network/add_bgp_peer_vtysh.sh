#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" -o "$2" == "" ] && echo "usage: $0 <peer_ip> <peer_asn>" && exit 1 

CMD="vtysh -e \"configure terminal\" -e \"router bgp ${ASN}\" -e \"neighbor ${1} remote-as ${2}\" -e \"exit\" -e \"exit\" -e \"write\""

eval ${CMD}
