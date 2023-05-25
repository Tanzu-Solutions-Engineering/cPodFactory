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
echo "Network information:"
echo

CPODS=$(govc find . -type ResourcePool | grep "cPod-Workload/cPod-")
printf "CPODNAME\t\tUSED\tTOTAL\tRATIO\n"
USED=0
TOTAL=0
for CPOD in ${CPODS}; do
        USEDCPOD=0
        TOTALCPOD=0
        echo ${CPOD}
        VMS=$(govc find ${CPOD} -type VirtualMachine)        
        for VM in ${VMS}; do
                printf "\t${VM}"
                STORAGEJSON=$(govc vm.info -json  ${VM} | jq -r '.VirtualMachines[].Storage.PerDatastoreUsage[]')
                USEDVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Committed)
                USEDVMSTORAGEGB=$(expr $USEDVMSTORAGERAW / 1024 / 1024 / 1024 )
                TOTALVMSTORAGERAW=$(echo ${STORAGEJSON} | jq -r .Uncommitted)
                TOTALVMSTORAGEGB=$(expr $TOTALVMSTORAGERAW / 1024 / 1024 / 1024 )
                RATIO=$(expr $USEDVMSTORAGERAW / $TOTALVMSTORAGERAW)
                printf "\t${USEDVMSTORAGEGB}\t${TOTALVMSTORAGEGB}\t${RATIO}%\n"
                USEDCPOD=$(expr ${USEDCPOD} + ${USEDVMSTORAGERAW})
                TOTALCPOD=$(expr ${TOTALCPOD} + ${TOTALVMSTORAGERAW})
        done
        USEDCPODGB=$(expr $USEDCPOD / 1024 / 1024 / 1024 )
        TOTALCPODGB=$(expr $TOTALCPOD / 1024 / 1024 / 1024 )
        RATIO=$(expr $USEDCPOD / $TOTALCPOD)
        printf "\t${USEDCPODGB}\t${TOTALCPODGB}\t${RATIO}%\n"
        USED=$(expr ${USED} + ${USEDCPOD})
        TOTAL=$(expr ${TOTAL} + ${TOTALCPOD})
done
USEDGB=$(expr $USED / 1024 / 1024 / 1024 )
TOTALGB=$(expr $TOTAL / 1024 / 1024 / 1024 )
RATIO=$(expr $USED / $TOTAL)
printf "\t${USEDGB}\t${TOTALGB}\t${RATIO}%\n"
