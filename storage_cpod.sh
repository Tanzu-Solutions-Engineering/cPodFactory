#!/bin/bash
#edewitte@vmware.com

. ./env
. ./govc_env

. ./${COMPUTE_DIR}/cpod-xxx_env

### functions ####

source ./extra/functions.sh

### Local vars ####

echo =====================
echo "cPods Storage Summary" 
echo =====================
echo

CPODSTORAGE='{ "cpods" : [], "TotalStorageUsed" : 0 }'

CPODS=$(govc find . -type ResourcePool | grep "cPod-Workload/cPod-")
#printf "CPODNAME\t\tUSED\tTOTAL\tRATIO\n"
USED=0
TOTAL=0
for CPOD in ${CPODS}; do
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.cpods += [{"cPodName":"'${CPOD}'","TotalStorageUsed":0,"VirtualMachines":[]}]')
        echo "${CPODSTORAGE}" | jq .
        USEDCPOD=0
        TOTALCPOD=0
        #printf "${CPOD}"
        VMS=$(govc find ${CPOD} -type VirtualMachine)        
        for VM in ${VMS}; do
                #printf "\t${VM}"
                STORAGEJSON=$(govc vm.info -json  ${VM} | jq -r '.VirtualMachines[].Storage.PerDatastoreUsage[]')
                USEDVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Committed)
                USEDVMSTORAGEGB=$(expr $USEDVMSTORAGERAW / 1024 / 1024 / 1024 )
                TOTALVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Uncommitted)
                TOTALVMSTORAGEGB=$(expr $TOTALVMSTORAGERAW / 1024 / 1024 / 1024 )
                RATIO=$(( USEDVMSTORAGERAW * 100 / TOTALVMSTORAGERAW ))
               # printf "\t${USEDVMSTORAGEGB}\t${TOTALVMSTORAGEGB}\t${RATIO}%%\n"
                USEDCPOD=$(expr ${USEDCPOD} + ${USEDVMSTORAGERAW})
                TOTALCPOD=$(expr ${TOTALCPOD} + ${TOTALVMSTORAGERAW})
                CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).VirtualMachines += [{"VMName":"'${VM}'","UsedStorage":'${USEDVMSTORAGEGB}'}]')
                echo "${CPODSTORAGE}" | jq .
        done
        USEDCPODGB=$(expr $USEDCPOD / 1024 / 1024 / 1024 )
        TOTALCPODGB=$(expr $TOTALCPOD / 1024 / 1024 / 1024 )
        RATIO=$(( USEDCPOD * 100 / TOTALCPOD ))
        #printf "\t${USEDCPODGB}\t${TOTALCPODGB}\t${RATIO}%%\n"
        USED=$(expr ${USED} + ${USEDCPOD})
        TOTAL=$(expr ${TOTAL} + ${TOTALCPOD})
        CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '(.cpods[] | select (.cPodName == "'${CPOD}'")).TotalStorageUsed |= '${TOTALCPOD}'')
        echo "${CPODSTORAGE}" | jq .
done
USEDGB=$(expr $USED / 1024 / 1024 / 1024 )
TOTALGB=$(expr $TOTAL / 1024 / 1024 / 1024 )
if [[ $TOTAL -gt 0 ]]
then
        RATIO=$(( USED * 100 / TOTAL ))
fi
CPODSTORAGE=$(echo "${CPODSTORAGE}" | jq '.TotalStorageUsed |= '${TOTAL}'')
echo "${CPODSTORAGE}" > /tmp/cpods_storage.json
echo "${CPODSTORAGE}" | jq .