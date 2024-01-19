#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

CPODS=$(cat /etc/hosts |grep cpod- | wc -l)

echo =====================
echo "CPODS in AZ-${SPEC} : ${CPODS}" 
echo =====================
echo "govc version : $(govc version)"
echo =====================
echo "ESXi Hosts Status Info"
echo
govc ls host | xargs govc ls -json  | jq -r '.elements[].Object| select (.Self.type == "HostSystem") | [.name, .runtime.connectionState, .runtime.powerState] |@tsv '  #govc jq checked
echo
echo =====================
echo "Storage Info"
echo
#govc datastore.info ${DATASTORE} | grep -e Name -e Capacity -e Free
govc datastore.info -json  |jq -r '["Name","Capacity","Free","Used%" ], (.datastores[].summary | select ( .multipleHostAccess == true ) |  [.name, (.capacity/1024/1024/1024|floor), (.freeSpace/1024/1024/1024|floor), (((.capacity-.freeSpace)*100/.capacity)|floor)] )|@tsv ' | column -t  #govc jq checked

DATASTOREFREE=$(govc datastore.info ${DATASTORE} | grep Free | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g")
DATASTOREFREE=$( echo "${DATASTOREFREE}/1" | bc )
DATASTOREFREE=$( expr ${DATASTOREFREE} )

DATASTORECAP=$(govc datastore.info ${DATASTORE} | grep Capacity | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g")
DATASTORECAP=$( echo "${DATASTORECAP}/1" | bc )
DATASTORECAP=$( expr ${DATASTORECAP} )

PERCENTFULL=$(echo "scale=0; 100*($DATASTORECAP-$DATASTOREFREE)/$DATASTORECAP" |bc)
[[ $PERCENTFULL -gt 70 ]] && STORAGESTATUS="!! alert !!" || STORAGESTATUS="ok"
echo
echo "Status ${DATASTORE}  : $PERCENTFULL% Full - ${STORAGESTATUS}"
echo =====================

CPU=$( govc metric.sample "host/${VCENTER_CLUSTER}" cpu.usage.average | sed -e "s/,.*$//" | cut -f9 -d" " | cut -f1 -d"." )
CPU=$( expr ${CPU} )
echo "CPU : ${CPU}% avg"

MEM=$( govc metric.sample "host/${VCENTER_CLUSTER}" mem.usage.average | sed -e "s/,.*$//" | cut -f9 -d" " | cut -f1 -d"." )
MEM=$( expr ${MEM} )
echo "Memory : ${MEM}% avg"
echo =====================

EDGESTORAGE=$(df -h | grep "/$" | rev | awk '{print $2}' | rev | sed 's/%//')
[[ $EDGESTORAGE -gt 90 ]] && EDGESTATUS="!! alert !!" || EDGESTATUS="ok"
echo "cPodEdge '/' : ${EDGESTORAGE}% - ${EDGESTATUS}"
EDGESTORAGE=$(df -h $CPODEDGE_DATASTORE | grep "/" | rev | awk '{print $2}' | rev | sed 's/%//')
[[ $EDGESTORAGE -gt 90 ]] && EDGESTATUS="!! alert !!" || EDGESTATUS="ok"
echo "cPodEdge $CPODEDGE_DATASTORE : ${EDGESTORAGE}% - ${EDGESTATUS}"
echo =====================

SCRIPTDIR="/tmp/scripts"
if [ ! -d "$SCRIPTDIR" ]; then
    mkdir -p "$SCRIPTDIR"
    chmod 750 "$SCRIPTDIR"
fi
