#!/bin/bash
#edewitte@vmware.com

### functions ####

source ./extra/functions.sh


### Local vars ####

STORAGEJSON="/tmp/cpods_storage.json"

### Main Code ####

#check if the json already exists otherwise call script to create it
if [ ! -f "${STORAGEJSON}" ]; then
  ./storage_cpod.sh
fi

CPODSTORAGE=$(cat "${STORAGEJSON}")

CPODS=$(echo "${CPODSTORAGE}" | jq -r .cpods[].cPodName )
for CPOD in ${CPODS}; do
        echo
        echo =======================================
        echo "${CPOD}"
        echo
        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        VMS=$(echo  "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") | .VirtualMachines[].VMName ')
        echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodName == "'${CPOD}'") | .VirtualMachines[] | ["VM","TotalUsedGB","Ratio-vs-Total"], ["----","-----------","------------"], ([.VMShortName, .UsedStorageGB, .CpodPercent] ) | @tsv' | column -t | sed  -e 's/^/     /'       
done
