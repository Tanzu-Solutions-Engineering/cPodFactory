#!/bin/bash
#edewitte@vmware.com

### SDDC Mgr functions ####

get_sddc_token(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"
    TOKEN=$(curl -s -k -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens | jq -r .accessToken)
    echo "${TOKEN}"
}

get_network_pools(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCNETPOOLS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq '.elements[] | {id, name}')
    echo "$SDDCNETPOOLS"
}

get_hosts_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
    echo "$SDDCHOSTS"
}

get_hosts_fqdn(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq -r '.elements[].fqdn')
    echo "$SDDCHOSTS"
}

get_hosts_unassigned(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
    echo "${VALIDATIONRESULT}" | jq -r '.elements[].fqdn'
}


get_validation_status(){
	VALIDATIONID="${1}"
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations/${VALIDATIONID})
	echo "${VALIDATIONRESULT}" > /tmp/scripts/validation-test.json
	echo "${VALIDATIONRESULT}"
}

get_commission_status(){
    COMMISSIONID="${1}"
	COMMISSIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${COMMISSIONID})
	echo "${COMMISSIONRESULT}" > /tmp/scripts/commissionresult.json
	echo "${COMMISSIONRESULT}"
}

get_license_keys_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/license-keys)
    echo "$SDDCHOSTS"
}


loop_wait_validation(){
    VALIDATIONID="${1}"
    RESPONSE=$(get_validation_status "${VALIDATIONID}")
    if [[ "${RESPONSE}" == *"ERROR - HTTPSTATUS"* ]] || [[ "${RESPONSE}" == "" ]]
    then
        echo "problem getting initial validation ${VALIDATIONID} status : "
        echo "${RESPONSE}"
    else
        STATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
        echo "${STATUS}"
    fi

    CURRENTSTATE=${STATUS}
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    while [[ "$STATUS" != "COMPLETED" ]]
    do      
        RESPONSE=$(get_validation_status "${VALIDATIONID}")
        #echo "${RESPONSE}" |jq .
        if [[ "${RESPONSE}" == *"ERROR"* ]] || [[ "${RESPONSE}" == "" ]]
        then
            echo
            echo "problem getting deployment ${VALIDATIONID} status : "
            echo "${RESPONSE}"		
        else
            STATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
            MAINTASK=$(echo "${RESPONSE}" | jq -r '.description')
            SUBTASK=$(echo "${RESPONSE}" | jq -r '.validationChecks[] | select ( .resultStatus | contains("IN_PROGRESS")) |.name')

            if [[ "${MAINTASK}" != "${CURRENTMAINTASK}" ]] 
            then
                printf "\t%s" "${MAINTASK}"
                CURRENTMAINTASK="${MAINTASK}"
            fi	
            if [[ "${SUBTASK}" != "${CURRENTSTEP}" ]] 
            then
                if [ "${CURRENTSTEP}" != ""  ]
                then
                    FINALSTATUS=$(echo "${RESPONSE}" | jq -r '.validationChecks[]| select ( .name == "'"${CURRENTSTEP}"'") |.status')
                    printf "\t%s" "${FINALSTATUS}"
                fi
                printf "\n\t\t%s" "${SUBTASK}"
                CURRENTSTEP="${SUBTASK}"
            fi
        fi
        if [[ "${STATUS}" == "FAILED" ]] 
        then 
            echo
            echo "FAILED"
            echo "${VALIDATIONRESULT}" | jq .
            echo "stopping script"
            exit 1
        fi
        printf '.' >/dev/tty
        sleep 2
    done
    RESPONSE=$(get_validation_status "${VALIDATIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')

    echo
    echo "Host Validation Result Status : $RESULTSTATUS"

    if [ "${RESULTSTATUS}" != "SUCCEEDED" ]
    then
        echo "Validation not succesful. Quitting"
        exit
    fi

}

loop_wait_commissioning(){
    COMMISSIONID="${1}"
    STATUS=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    FINALSTATUS=""
    while [[ "${STATUS}" != "Successful" ]]
    do      
        RESPONSE=$(get_commission_status "${COMMISSIONID}")
        #echo "${RESPONSE}" |jq .
        if [[ "${RESPONSE}" == *"ERROR"* ]] || [[ "${RESPONSE}" == "" ]]
        then
            echo "problem getting deployment ${COMMISSIONID} status : "
            echo "${RESPONSE}"		
        else
            STATUS=$(echo "${RESPONSE}" | jq -r '.status')
            MAINTASK=$(echo "${RESPONSE}" | jq -r '.subTasks[] | select ( .status | contains("IN_PROGRESS")) |.description')
            TASKNAME=$(echo "${RESPONSE}" | jq -r '.subTasks[] | select ( .status | contains("IN_PROGRESS")) |.name')
            
            if [[ "${TASKNAME}" != "${CURRENTMAINTASK}" ]] 
            then
                if [ "${CURRENTMAINTASK}" != ""  ]
                then
                    FINALSTATUS=$(echo "${RESPONSE}" | jq -r '.subTasks[]| select ( .name == "'"${CURRENTMAINTASK}"'") |.status')
                    printf "\t%s" "${FINALSTATUS}"
                fi
                printf "\n\t%s" "${MAINTASK}"
                CURRENTMAINTASK="${TASKNAME}"
            fi	
             printf '.' >/dev/tty
        fi
        if [[ "${STATUS}" == "FAILED" ]] 
        then 
            echo
            echo "FAILED"
            echo "${RESPONSE}" | jq .
            echo "stopping script"
            exit 1
        fi
        sleep 2
    done
    RESPONSE=$(get_commission_status "${COMMISSIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.status')
    echo
    echo "Host Commisioning Result Status : $RESULTSTATUS"    
}

###################
