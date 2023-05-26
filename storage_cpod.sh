#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

. ./${COMPUTE_DIR}/cpod-xxx_env

### functions ####

source ./extra/functions.sh

calc() { 
        awk "BEGIN{ printf \"%.2f\n\", $* }"; 
}

### Local vars ####

echo ===============================
echo "Collecting cPods Storage data" 
echo ===============================
echo

CPODSTORAGE='{ "cpods" : [], "TotalStorageUsedRaw" : 0, "TotalStorageUsedGB" : 0 }'

CPODS=$(govc find . -type ResourcePool | grep "cPod-Workload/cPod-")
#printf "CPODNAME\t\tUSED\tTOTAL\tRATIO\n"
USED=0
TOTAL=0
for CPOD in ${CPODS}; do
        echo "${CPOD}"
        CPODSHORTNAME=$(echo "${CPOD}" | rev | cut -d "/" -f1 | rev)
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.cpods += [{ "cPodName": "'${CPOD}'", "cPodShortName" : "'${CPODSHORTNAME}'", "TotalStorageUsedRaw" : 0, "TotalStorageUsedGB" : 0, "TotalRatio" : "", "VirtualMachines" : [] }]')
        #echo "${CPODSTORAGE}" | jq .
        USEDCPOD=0
        TOTALCPOD=0
        #printf "${CPOD}"
        VMS=$(govc find ${CPOD} -type VirtualMachine)        
        for VM in ${VMS}; do
                #printf "\t${VM}"
                echo "${VM}"
                STORAGEJSON=$(govc vm.info -json  ${VM} | jq -r '.VirtualMachines[].Storage.PerDatastoreUsage[]')
                USEDVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Committed)
                USEDVMSTORAGEGB=$(expr $USEDVMSTORAGERAW / 1024 / 1024 / 1024 )
                TOTALVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Uncommitted)
                TOTALVMSTORAGEGB=$(expr $TOTALVMSTORAGERAW / 1024 / 1024 / 1024 )
                RATIO=$(( USEDVMSTORAGERAW * 100 / TOTALVMSTORAGERAW ))
               # printf "\t${USEDVMSTORAGEGB}\t${TOTALVMSTORAGEGB}\t${RATIO}%%\n"
                USEDCPOD=$(expr ${USEDCPOD} + ${USEDVMSTORAGERAW})
                TOTALCPOD=$(expr ${TOTALCPOD} + ${TOTALVMSTORAGERAW})
                CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).VirtualMachines += [{"VMName":"'${VM}'","UsedStorageGB":'${USEDVMSTORAGEGB}',"UsedStorageRaw":'${USEDVMSTORAGERAW}',"CpodPercent":""}]')
                #echo "${CPODSTORAGE}" | jq .
        done
        USEDCPODGB=$(expr $USEDCPOD / 1024 / 1024 / 1024 )
        TOTALCPODGB=$(expr $TOTALCPOD / 1024 / 1024 / 1024 )
        RATIO=$(( USEDCPOD * 100 / TOTALCPOD ))
        #printf "\t${USEDCPODGB}\t${TOTALCPODGB}\t${RATIO}%%\n"
        USED=$(expr ${USED} + ${USEDCPOD})
        TOTAL=$(expr ${TOTAL} + ${TOTALCPOD})
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalStorageUsedRaw |= '${TOTALCPOD}'')
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalStorageUsedGB |= '${TOTALCPODGB}'')
        #echo "${CPODSTORAGE}" | jq .
done
USEDGB=$(expr $USED / 1024 / 1024 / 1024 )
TOTALGB=$(expr $TOTAL / 1024 / 1024 / 1024 )
if [[ $TOTAL -gt 0 ]]
then
        RATIO=$(( USED * 100 / TOTAL ))
fi
CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.TotalStorageUsedRaw |= '${TOTAL}'')
CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.TotalStorageUsedGB |= '${TOTALGB}'')

for CPOD in ${CPODS}; do
        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        CPODRATIO=$(calc $CPODTOTAL*100/$TOTAL )
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalRatio |= "'${CPODRATIO}'%"')
        VMS=$(echo  "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") | .VirtualMachines[].VMName ')
        for VM in ${VMS}; do
                VMTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") | .VirtualMachines[] | select (.VMName == "'${VM}'") |.UsedStorageRaw' )
                VMRATIO=$(calc $VMTOTAL*100/$CPODTOTAL )
                CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'") | .VirtualMachines[] | select (.VMName == "'${VM}'")).CpodPercent |= "'${VMRATIO}'%"' )
        done
done

echo "${CPODSTORAGE}" > /tmp/cpods_storage.json
clear
echo =======================================
echo "Overview of cPods Storage consumption" 
echo =======================================
echo
echo "${CPODSTORAGE}" | jq -r '["CPOD","TotalUsedGB","Ratio-vs-Total"], ["----","-----------","------------"], (.cpods[] | [.cPodShortName, .TotalStorageUsedGB, .TotalRatio] ) | @tsv' | column -t

