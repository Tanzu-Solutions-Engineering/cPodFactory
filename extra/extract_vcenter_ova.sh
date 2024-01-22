#!/bin/bash
#edewitte@vmware.com

# $1 : path to vCenter iso file

[ "$1" == "" ] && echo "usage: $0 <path_to_ISO_file>"  && echo "usage example: $0 /data/BITS/VMware-VCSA-all-7.0.3-20150588.iso" && exit 1

START=$( date +%s ) 

source ./env

shortIsoFileName=$(echo $1 | sed 's/.*\///')

#using vm forty-two to extract iso file
echo
echo "======================="
echo "extracting OVA from ISO"
echo "======================="

scp $1 root@forty-two:/tmp/cpod-template
ssh root@forty-two "mount /tmp/cpod-template/${shortIsoFileName} /media/ -o loop "
scp root@forty-two:/media/vcsa/*.ova ${CPODEDGE_DATASTORE}
ssh root@forty-two "umount /media/"
ssh root@forty-two "rm /tmp/cpod-template/${shortIsoFileName}"
END=$( date +%s )
TIME=$( expr ${END} - ${START} )
TIME=$(date -d@$TIME -u +%Hh%Mm%Ss)

echo
echo "========================================="
echo "=== OVA extraction is finished ==="
echo "=== In ${TIME} "
echo "========================================="