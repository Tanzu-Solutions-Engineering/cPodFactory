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
else
        if [[ $(find "${STORAGEJSON}" -mtime +1 -print) ]]; then
                # "File $filename exists and is older than 1 day"
                ./storage_cpod.sh
        fi
fi

CPODSTORAGE=$(cat "${STORAGEJSON}")

CPODS=$(echo "${CPODSTORAGE}" | jq -r .cpods[].cPodShortName )
for CPOD in ${CPODS}; do

        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        CPODTOTALGB=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalStorageUsedGB' )
        CPODRATIO=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalRatio' )

        echo
        echo =======================================
        echo "${CPOD}   ${CPODTOTALGB}    ${CPODRATIO} vs Factory"
        echo
        CPODTOTAL=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalStorageUsedRaw' )
        CPODRATIO=$(echo "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") |.TotalRatio' )

        VMS=$(echo  "${CPODSTORAGE}" | jq -r '.cpods[] | select (.cPodShortName == "'${CPOD}'") | .VirtualMachines[].VMName ')
        echo "${CPODSTORAGE}" | jq -r '["VM","TotalUsedGB","Ratio-vs-Cpod"], ["----","-----------","------------"], (.cpods[] | select (.cPodShortName == "'${CPOD}'") | .VirtualMachines[] | [.VMShortName, .UsedStorageGB, .CpodPercent] ) | @tsv' | column -t | sed  -e 's/^/     /'       
done
