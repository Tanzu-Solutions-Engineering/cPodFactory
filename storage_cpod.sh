#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

. ./${COMPUTE_DIR}/cpod-xxx_env

### functions ####

source ./extra/functions.sh

### Main Code ####

echo ===============================
echo "Collecting cPods Storage data" 
echo ===============================
echo

CPODSTORAGE='{ "cpods" : [], "TotalStorageUsedRaw" : 0, "TotalStorageUsedGB" : 0 }'

CPODS=$(govc find . -type ResourcePool | grep "cPod-Workload/cPod-")
USED=0
for CPOD in ${CPODS}; do
        echo "${CPOD}"
        CPODSHORTNAME=$(echo "${CPOD}" | rev | cut -d "/" -f1 | rev)
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.cpods += [{ "cPodName": "'${CPOD}'", "cPodShortName" : "'${CPODSHORTNAME}'", "TotalStorageUsedRaw" : 0, "TotalStorageUsedGB" : 0, "TotalRatio" : "", "VirtualMachines" : [] }]')
        USEDCPOD=0
        VMS=$(govc find ${CPOD} -type VirtualMachine)        
        for VM in ${VMS}; do
                echo "${VM}"
                STORAGEJSON=$(govc vm.info -json  ${VM} | jq -r '.virtualMachines[].storage.perDatastoreUsage[]') # govc jq checked
                USEDVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .committed) # govc jq checked
                USEDVMSTORAGEGB=$(calc0 $USEDVMSTORAGERAW / 1024 / 1024 / 1024 )
                USEDCPOD=$(calc0 ${USEDCPOD} + ${USEDVMSTORAGERAW})
                VMSHORTNAME=$(echo "${VM}" | rev | cut -d "/" -f1 | rev)
                CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).VirtualMachines += [{"VMName":"'${VM}'","VMShortName":"'${VMSHORTNAME}'","UsedStorageGB":'${USEDVMSTORAGEGB}',"UsedStorageRaw":'${USEDVMSTORAGERAW}',"CpodPercent":""}]')
        done
        USEDCPODGB=$(calc0 $USEDCPOD / 1024 / 1024 / 1024 )
        USED=$(calc0 ${USED} + ${USEDCPOD})
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalStorageUsedRaw |= '${USEDCPOD}'')
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalStorageUsedGB |= '${USEDCPODGB}'')
done
USEDGB=$(calc0 $USED / 1024 / 1024 / 1024 )
CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.TotalStorageUsedRaw |= '${USED}'')
CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.TotalStorageUsedGB |= '${USEDGB}'')

for CPOD in ${CPODS}; do
        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        CPODRATIO=$(calc $CPODTOTAL*100/$USED )
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

