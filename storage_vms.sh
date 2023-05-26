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

CPODS=$(echo "${CPODSTORAGE}" | jq -r .cpods[].cPodShortName )
for CPOD in ${CPODS}; do
        echo
        echo =======================================
        echo "${CPOD}"
        echo
        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        VMS=$(echo  "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") | .VirtualMachines[].VMName ')
        echo "${CPODSTORAGE}" | jq -r '["VM","TotalUsedGB","Ratio-vs-Cpod"], ["----","-----------","------------"], (.cpods[] | select (.cPodShortName == "'${CPOD}'") | .VirtualMachines[] | [.VMShortName, .UsedStorageGB, .CpodPercent] ) | @tsv' | column -t | sed  -e 's/^/     /'       
done
