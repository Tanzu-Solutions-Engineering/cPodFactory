#!/bin/bash
#edewitte@vmware.com

### cloudbuilder functions ####

get_cloudbuilder_status() {
    NAME_LOWER="${1}"
    PASSWORD="${2}"
    #make the curl more readable
    URL="https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}"
    AUTH="admin:${PASSWORD}"

    #returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}' -u ${AUTH} -X GET ${URL}/v1/sddcs/validations )
    HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
    case $HTTPSTATUS in

            20[0-9])    
                    echo "READY"
                    ;;
            50[0-9])    
                    echo "Not Ready"
                    ;;
            *)      
                    echo ${RESPONSE} |awk -F '####' '{print $1}'
                    ;;

        esac
}

cloudbuilder_check_ready(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"

    echo
    printf "Trying to connect to cloudbuilder ."
    INPROGRESS=""
    CURRENTSTATE=${INPROGRESS}
    while [[ "$INPROGRESS" != "READY" ]]
    do      
            INPROGRESS=$(get_cloudbuilder_status "${NAME_LOWER}" "${PASSWORD}")
            if [ "${INPROGRESS}" != "${CURRENTSTATE}" ] 
            then 
                    printf "\n\t%s" "${INPROGRESS}"
                    CURRENTSTATE="${INPROGRESS}"
            fi
            if [ "$INPROGRESS" != "READY" ]
            then
                printf '.' >/dev/tty
                sleep 10
            fi
        done
    echo
    echo
    echo "Cloudbuilder API : READY"
}

cloudbuilder_get_deployment_status() {
	#returns json
    NAME_LOWER=$1
    PASSWORD=$2
    DEPLOYMENTID=$3

	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/${DEPLOYMENTID})
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			VALIDATIONJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
			EXECUTIONSTATUS=$(echo ${VALIDATIONJSON})
			echo "${EXECUTIONSTATUS}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/cloudbuilder-deployment-httpstatus-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${DEPLOYMENTID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/cloudbuilder-deployment-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

cloudbuilder_get_validation_status() {
	#returns json
    NAME_LOWER=$1
    PASSWORD=$2
    VALIDATIONID=$3

	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations/${VALIDATIONID})

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			VALIDATIONJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
            echo "${VALIDATIONJSON}" > /tmp/scripts/cloudbuilder-validation-status-$$.json
			echo "${VALIDATIONJSON}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/cloudbuilder-validation-httpstatus-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${VALIDATIONID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/cloudbuilder-validation-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

cloudbuilder_check_validation_list(){
    	#returns json
    NAME_LOWER=$1
    PASSWORD=$2

	RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}/v1/sddcs/validations)

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			VALIDATIONJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
			echo "${VALIDATIONJSON}" | jq '.elements[] | {id: .id, status: .executionStatus}'
			;;
		5[0-9][0-9])    
			echo '{status: "Not Ready"}'
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac

}

cloudbuilder_get_validation_result_table(){
    NAME_LOWER=$1
    PASSWORD=$2
    VALIDATIONID=$3

    RESPONSE=$(cloudbuilder_get_validation_status "${NAME_LOWER}" "${PASSWORD}" "${VALIDATIONID}")

    echo
    echo "Cloudbuilder Deployment tasks result overview"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.validationChecks[] | [.description,.resultStatus] )| @tsv' | column -t -s $'\t'

    echo
    echo "Cloudbuilder Deployment Status"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status","execution"],[.description,.resultStatus,.executionStatus]| @tsv'  | column -t -s $'\t'
}

cloudbuilder_get_deployment_result_table(){
    NAME_LOWER=$1
    PASSWORD=$2
    DEPLOYMENTID=$3

    RESPONSE=$(cloudbuilder_get_deployment_status "${NAME_LOWER}" "${PASSWORD}" "${DEPLOYMENTID}")

    echo
    echo "Cloudbuilder Validation tasks result overview"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.sddcSubTasks[] | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Cloudbuilder Validation Status"
    echo
    echo "${RESPONSE}" | jq -r '["ID","Name","Status"],[.id,.name,.status]| @tsv'  | column -t -s $'\t'
}

cloudbuilder_loop_wait_deployment_status(){

    NAME_LOWER=$1
    PASSWORD=$2
    DEPLOYMENTID=$3

    CURRENTSTATE=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    while [[ "$STATUS" != "COMPLETED_WITH_SUCCESS" ]]
    do      
        RESPONSE=$(cloudbuilder_get_deployment_status "${NAME_LOWER}" "${PASSWORD}" "${DEPLOYMENTID}")
        if [[ "${RESPONSE}" == *"ERROR - HTTPSTATUS"* ]] || [[ "${RESPONSE}" == "" ]]
        then
            echo "problem getting deployment ${DEPLOYMENTID} status : "
            echo "${RESPONSE}"		
        else
            STATUS=$(echo "${RESPONSE}" | jq -r '.status')
            MAINTASK=$(echo "${RESPONSE}" | jq -r '.sddcSubTasks[] | select ( .status | contains("IN_PROGRESS")) |.description')
            SUBTASK=$(echo "${RESPONSE}" | jq -r '.sddcSubTasks[] | select ( .status | contains("IN_PROGRESS")) |.name')

            if [[ "${MAINTASK}" != "${CURRENTMAINTASK}" ]] 
            then
                printf "\n%s" "${MAINTASK}"
                CURRENTMAINTASK="${MAINTASK}"
            fi	
            if [[ "${SUBTASK}" != "${CURRENTSTEP}" ]] 
            then
                if [ "${CURRENTSTEP}" != ""  ]
                then
                    FINALSTATUS=$(echo "${RESPONSE}" | jq -r '.sddcSubTasks[]| select ( .name == "'"${CURRENTSTEP}"'") |.status')
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
            echo ${VALIDATIONRESULT} | jq .
            echo "stopping script"
            exit 1
        fi
        printf '.' >/dev/tty
        sleep 2
    done
    cloudbuilder_get_deployment_result_table "${NAME_LOWER}" "${PASSWORD}" "${DEPLOYMENTID}"
}

cloudbuilder_loop_wait_validation_status(){

    NAME_LOWER=$1
    PASSWORD=$2
    VALIDATIONID=$3

    echo "Checking validationID: $VALIDATIONID"

    STATUS=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    while [[ "$STATUS" != "COMPLETED" ]]
    do      
        RESPONSE=$(cloudbuilder_get_validation_status "${NAME_LOWER}" "${PASSWORD}" "${VALIDATIONID}")
        if [[ "${RESPONSE}" == *"ERROR - HTTPSTATUS"* ]] || [[ "${RESPONSE}" == "" ]]
        then
            echo "problem getting validation  ${VALIDATIONID} status : "
            echo "${RESPONSE}"		
        else
            STATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
            [ $? -gt 0 ] && echo "Status parsing error"
            MAINTASK=$(echo "${RESPONSE}" | jq -r '.validationChecks[] | select ( .resultStatus | contains("IN_PROGRESS")) |.description')
            [ $? -gt 0 ] && echo "maintask  parsing error" && echo "${RESPONSE}" 
            if [[ "${MAINTASK}" != "${CURRENTMAINTASK}" ]] 
            then
                if [ "${CURRENTMAINTASK}" != ""  ]
                then
                    FINALSTATUS=$(echo "${RESPONSE}" | jq -r '.validationChecks[]| select ( .description == "'"${CURRENTMAINTASK}"'") |.resultStatus')
                    printf "\t%s" "${FINALSTATUS}"
                fi
                printf "\n\t%s" "${MAINTASK}"
                CURRENTMAINTASK="${MAINTASK}"
            fi
        fi
        if [[ "${STATUS}" == "FAILED" ]] 
        then 
            echo
            echo "FAILED"
            echo "${RESPONSE}" | jq .
            echo ""
            echo "stopping script"
            exit 1
        fi
        printf '.' >/dev/tty
        sleep 2
    done
    
    cloudbuilder_get_validation_result_table "${NAME_LOWER}" "${PASSWORD}" "${VALIDATIONID}"
}

### SDDC Mgr functions ####

sddc_get_manager_status() {
    NAME_LOWER="${1}"
    PASSWORD="${2}"

    #returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}' -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens )
    HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
    case $HTTPSTATUS in

            20[0-9])    
                    echo "READY"
                    ;;
            50[0-9])    
                    echo "Not Ready"
                    ;;
            *)      
                    echo ${RESPONSE} |awk -F '####' '{print $1}'
                    ;;

        esac
}

sddc_check_manager_ready(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"

    printf "\t connecting to sddc mgr ."
    INPROGRESS=""
    CURRENTSTATE=${INPROGRESS}
    while [[ "$INPROGRESS" != "READY" ]]
    do      
            INPROGRESS=$(sddc_get_manager_status "${NAME_LOWER}" "${PASSWORD}")
            if [ "${INPROGRESS}" != "${CURRENTSTATE}" ] 
            then 
                    printf "\n\t%s" "${INPROGRESS}"
                    CURRENTSTATE="${INPROGRESS}"
            fi
            if [ "$INPROGRESS" != "READY" ]
            then
                printf '.' >/dev/tty
                sleep 10
            fi
        done
    echo
    echo
    echo "SDDC manager READY"
}

sddc_get_token(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"
    TOKEN=$(curl -s -k -X POST -H "Content-Type: application/json" -d '{"password":"'${PASSWORD}'","username":"administrator@'${NAME_LOWER}.${ROOT_DOMAIN}'"}' https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tokens | jq -r .accessToken)
    echo "${TOKEN}"
}

sddc_get_network_pools(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCNETPOOLS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/network-pools | jq '.elements[] | {id, name}')
    echo "$SDDCNETPOOLS"
}

sddc_get_hosts_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts)
    echo "$SDDCHOSTS"
}

sddc_get_personalities_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/personalities)
    echo "$SDDCHOSTS"
}

sddc_get_hosts_fqdn(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq -r '.elements[].fqdn')
    echo "$SDDCHOSTS"
}

sddc_get_hosts_unassigned(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  'https://sddc.'${NAME_LOWER}.${ROOT_DOMAIN}'/v1/hosts?status=UNASSIGNED_USEABLE')
    echo "${VALIDATIONRESULT}" | jq -r '.elements[].fqdn'
}

sddc_get_domain_validation_status(){
	VALIDATIONID="${1}"
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/domains/validations/${VALIDATIONID})
	echo "${VALIDATIONRESULT}" > /tmp/scripts/domain-validation-test.json
	echo "${VALIDATIONRESULT}"
}


sddc_get_hosts_validation_status(){
	VALIDATIONID="${1}"
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations/${VALIDATIONID})
	echo "${VALIDATIONRESULT}" > /tmp/scripts/hosts-validation-test.json
	echo "${VALIDATIONRESULT}"
}

sddc_get_commission_status(){
    COMMISSIONID="${1}"
	COMMISSIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${COMMISSIONID})
	echo "${COMMISSIONRESULT}" > /tmp/scripts/commissionresult.json
	echo "${COMMISSIONRESULT}"
}

sddc_get_license_keys_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/license-keys)
    echo "$SDDCHOSTS"
}

sddc_post_domain_validation() {
    NAME_LOWER="${1}"
    TOKEN="${2}"
    DOMAINJSON="${3}"
    #returns json
    RESPONSE=$(curl -s -k  -w '####%{response_code}' -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${DOMAINJSON} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/domains/validations)
    HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
    case $HTTPSTATUS in

            200)    
                    echo ${RESPONSE} |awk -F '####' '{print $1}'  | jq .
                    ;;

            503)    
                    echo "Not Ready"
                    ;;
            *)      
                        echo ${RESPONSE} |awk -F '####' '{print $1}'
                    ;;

    esac
}

sddc_post_domain_creation() {
    NAME_LOWER="${1}"
    TOKEN="${2}"
    DOMAINJSON="${3}"
    #returns json
    RESPONSE=$(curl -s -k  -w '####%{response_code}' -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -d @${DOMAINJSON} -X POST  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/domains)
    HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
    case $HTTPSTATUS in

            200)    
                    echo ${RESPONSE} |awk -F '####' '{print $1}'  | jq .
                    ;;

            503)    
                    echo "Not Ready"
                    ;;
            *)      
                        echo ${RESPONSE} |awk -F '####' '{print $1}'
                    ;;

    esac
}

sddc_get_validation_result_table(){
    VALIDATIONID="${1}"
    RESPONSE=$(sddc_get_domain_validation_status "${VALIDATIONID}")

    echo
    echo "Succesfull tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("SUCCESSFUL")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Pending tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("PENDING")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Failed tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("FAILED")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Commission Status"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status","Retryable"],[.status,.resolutionStatus,.isRetryable]| @tsv'  | column -t -s $'\t'
}

sddc_get_commission_result_table(){
    COMMISSIONID="${1}"
    RESPONSE=$(sddc_get_commission_status "${COMMISSIONID}")

    echo
    echo "Succesfull tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("SUCCESSFUL")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Pending tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("PENDING")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Failed tasks"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("FAILED")) | [.name,.status] )| @tsv' | column -t -s $'\t'

    echo
    echo "Commission Status"
    echo
    echo "${RESPONSE}" | jq -r '["Name","Status","Retryable"],[.status,.resolutionStatus,.isRetryable]| @tsv'  | column -t -s $'\t'
}

sddc_retry_commission(){
    COMMISSIONID="${1}"

	RESPONSE=$(curl -s -k -w '####%{response_code}' -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X PATCH  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/tasks/${COMMISSIONID})
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	RESULT=$(echo ${RESPONSE} |awk -F '####' '{print $1}')

	case $HTTPSTATUS in
		2[0-9][0-9])    
			echo "${RESULT}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/sddc-task-retry-httpstatus-4xx-$$.txt"
            echo "${RESULT}" > "${DUMPFILE}"
            echo "PARAMS - ${COMMISSIONID}" >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESULT}" > /tmp/scripts/sddc-task-retry-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESULT} |awk -F '####' '{print $1}'
			;;
	esac
}

sddc_loop_wait_domain_validation(){
    VALIDATIONID="${1}"
    RESPONSE=$(sddc_get_domain_validation_status "${VALIDATIONID}")
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
        RESPONSE=$(sddc_get_domain_validation_status "${VALIDATIONID}")
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
    RESPONSE=$(sddc_get_domain_validation_status "${VALIDATIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')

    echo
    echo "Host Validation Result Status : $RESULTSTATUS"

    if [ "${RESULTSTATUS}" != "SUCCEEDED" ]
    then
        echo "Domain Validation not succesful. Quitting"
        exit
    fi

}

sddc_loop_wait_hosts_validation(){
    VALIDATIONID="${1}"

    CURRENTSTATE=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    EXECUTIONSTATUS=""
    RESULTSTATUS=""
    while [[ "$EXECUTIONSTATUS" != "COMPLETED" ]]
    do      
        RESPONSE=$(sddc_get_hosts_validation_status "${VALIDATIONID}")
        #echo "${RESPONSE}" |jq .
        if [[ "${RESPONSE}" == *"ERROR"* ]] || [[ "${RESPONSE}" == "" ]]
        then
            echo
            echo "problem getting deployment ${VALIDATIONID} status : "
            echo "${RESPONSE}"		
            RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')
        else
            EXECUTIONSTATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
            RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')
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
        if [[ "${RESULTSTATUS}" == "FAILED" ]] 
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
    RESPONSE=$(sddc_get_hosts_validation_status "${VALIDATIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')

    echo
    echo "Host Validation Result Status : $RESULTSTATUS"

    if [ "${RESULTSTATUS}" != "SUCCEEDED" ]
    then
        echo "Validation not succesful. Quitting"
        exit
    fi

}

sddc_loop_wait_commissioning(){
    COMMISSIONID="${1}"
    STATUS=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    FINALSTATUS=""
    TOKENTIMER=0
    while [[ "${STATUS}" != "Successful" ]]
    do      
        RESPONSE=$(sddc_get_commission_status "${COMMISSIONID}")
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
        if [[ "${STATUS}" == "FAILED" ]] || [[ "${STATUS}" == "Failed" ]]
        then 
            echo
            echo "FAILED"
            echo "${RESPONSE}" | jq -r '["Name","Status"],["----","------"],(.subTasks[] | select ( .status | contains("FAILED")) | [.name,.status] )| @tsv' | column -t -s $'\t'
            RETRYABLE=$(echo "${RESPONSE}" | jq '.isRetryable')
            if [[ "${RETRYABLE}" == "true" ]]
            then
                echo "Retrying"
                sddc_retry_commission "${COMMISSIONID}"
            else
                echo "Not retryable - stopping script"
                exit 1
            fi
        fi
        TOKENTIMER=$((TOKENTIMER+1))
        if [[ $TOKENTIMER -gt 150 ]]
        then
            TOKEN=$(sddc_get_token "${NAME_LOWER}" "${PASSWORD}" )
        fi
        sleep 2
    done
    sddc_get_commission_result_table "${COMMISSIONID}"
}

sddc_domains_get(){
	#returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/domains)

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			DOMAINSJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
            echo "${DOMAINSJSON}" > /tmp/scripts/sddc-domains-status-$$.json
			echo "${DOMAINSJSON}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/sddc-domains-httpstatus-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${VALIDATIONID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/sddc-cluster-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

sddc_domains_id_get(){
    DOMAINNAME="${1}"
    DOMAINSJSON=$(sddc_domains_get)
    echo "${DOMAINSJSON}" | jq -r '.elements[] | select ( .name == "'"${DOMAINNAME}"'") | .id'
}

sddc_clusters_get(){
	#returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/clusters)

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			CLUSTERJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
            echo "${CLUSTERJSON}" > /tmp/scripts/sddc-cluster-status-$$.json
			echo "${CLUSTERJSON}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/sddc-cluster-httpstatus-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${VALIDATIONID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/sddc-cluster-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

sddc_cluster_id_get(){
    CLUSTERNAME="${1}"
    CLUSTERJSON=$(sddc_clusters_get)
    echo "${CLUSTERJSON}" | jq -r '.elements[] | select ( .name == "'"${CLUSTERNAME}"'") | .id'

}

sddc_edgecluster_get(){
	#returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' -H 'Accept: application/json' -X GET https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/edge-clusters)

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			EDGECLUSTERJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
            echo "${EDGECLUSTERJSON}" > /tmp/scripts/sddc-edgecluster-status-$$.json
			echo "${EDGECLUSTERJSON}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/sddc-edgecluster-httpstatus-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${VALIDATIONID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/sddc-edgecluster-httpstatus-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

sddc_edgecluster_create(){
    EDGECLUSTERJSONPATH="${1}"

	#returns json
    RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Authorization: Bearer ${TOKEN}" -H 'Content-Type: application/json' -H 'Accept: application/json'  -d @${EDGECLUSTERJSONPATH} -X POST https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/edge-clusters)

	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	case $HTTPSTATUS in
		2[0-9][0-9])    
			EDGECLUSTERJSON=$(echo "${RESPONSE}" |awk -F '####' '{print $1}')
            echo "${EDGECLUSTERJSON}" > /tmp/scripts/sddc-edgecluster-create-status-$$.json
			echo "${EDGECLUSTERJSON}"
			;;
		4[0-9][0-9])    
            DUMPFILE="/tmp/scripts/sddc-edgecluster-httpstatus-create-4xx-$$.txt"
            echo "${RESPONSE}" > "${DUMPFILE}"
            echo "PARAMS - ${NAME_LOWER} ${PASSWORD} ${VALIDATIONID} " >>  "${DUMPFILE}"
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/sddc-edgecluster-httpstatus-create-5xx-$$.txt
   			echo "{\"executionStatus\": \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}