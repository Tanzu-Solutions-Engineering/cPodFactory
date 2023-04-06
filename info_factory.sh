#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

CPODS=$(cat /etc/hosts |grep cpod- | wc -l)

echo =====================
echo "CPODS in AZ-${SPEC} : ${CPODS}" 
echo =====================
echo Storage Info
echo
govc datastore.info ${DATASTORE} | grep -e Name -e Capacity -e Free

DATASTOREFREE=$(govc datastore.info ${DATASTORE} | grep Free | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g")
DATASTOREFREE=$( echo "${DATASTOREFREE}/1" | bc )
DATASTOREFREE=$( expr ${DATASTOREFREE} )

DATASTORECAP=$(govc datastore.info ${DATASTORE} | grep Capacity | sed -e "s/^.*://" -e "s/GB//" -e "s/ //g")
DATASTORECAP=$( echo "${DATASTORECAP}/1" | bc )
DATASTORECAP=$( expr ${DATASTORECAP} )

PERCENTFULL=$(echo "scale=2; 100*($DATASTORECAP-$DATASTOREFREE)/$DATASTORECAP" |bc)
echo
echo "Status: $PERCENTFULL% Full"
echo =====================

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