#!/bin/bash
#edewitte@vmware.com


### CLOUDBUILDER functions ####

get_cloudbuilder_status() {
    NAME_LOWER="${1}"
    PASSWORD="${2}"
    #make the curl more readable
    URL="https://cloudbuilder.${NAME_LOWER}.${ROOT_DOMAIN}"
    AUTH="admin:${PASSWORD}"

    # while [ -z "$APICHECK" ]
    # do  
    #     echo "checking if the API on cloudbuilder ${URL} is ready yet..."
    #     APICHECK=$(curl -s -k -w '####%{response_code}' -u ${AUTH} -X GET ${URL}/v1/sddcs/validations)
    #     sleep 10
    #     TIMEOUT=$((TIMEOUT + 1))
    #     if [ $TIMEOUT -ge 48 ]; then
    #         echo "bailing out..."
    #         exit 1
    #     fi 
    # done
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

check_cloudbuilder_ready(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"

    printf "\t connecting to cloudbuilder ."
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

get_deployment_status() {
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
   			echo "{executionStatus: \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/cloudbuilder-deployment-httpstatus-5xx-$$.txt
   			echo "{executionStatus: \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

get_validation_status() {
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
   			echo "{executionStatus: \"$HTTPSTATUS - Bad Request\"}"
			;;
		5[0-9][0-9])    
            echo "${RESPONSE}" > /tmp/scripts/cloudbuilder-validation-httpstatus-5xx-$$.txt
   			echo "{executionStatus: \"$HTTPSTATUS - Server Error \"}"
			;;
		*)      
			echo ${RESPONSE} |awk -F '####' '{print $1}'
			;;
	esac
}

Check_validation_list(){
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

Loop_wait_deployment_status(){

    NAME_LOWER=$1
    PASSWORD=$2
    DEPLOYMENTID=$3

    CURRENTSTATE=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    while [[ "$STATUS" != "COMPLETED_WITH_SUCCESS" ]]
    do      
        RESPONSE=$(get_deployment_status "${NAME_LOWER}" "${PASSWORD}" "${DEPLOYMENTID}")
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
    
}

Loop_wait_validation_status(){

    NAME_LOWER=$1
    PASSWORD=$2
    VALIDATIONID=$3

    echo "Checking validationID: $VALIDATIONID"

    STATUS=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    while [[ "$STATUS" != "COMPLETED" ]]
    do      
        RESPONSE=$(get_validation_status "${NAME_LOWER}" "${PASSWORD}" "${VALIDATIONID}")
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
            echo ${VALIDATIONRESULT} | jq .
            echo "stopping script"
            exit 1
        fi
        printf '.' >/dev/tty
        sleep 2
    done
    EXECSTATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')
    echo
    echo "Validation  ${VALIDATIONID} - Execution : ${EXECSTATUS} - Result : ${RESULTSTATUS} "   
}

### SDDC Mgr functions ####

get_sddc_status() {
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

check_sddc_ready(){
    NAME_LOWER="${1}"
    PASSWORD="${2}"

    printf "\t connecting to sddc mgr ."
    INPROGRESS=""
    CURRENTSTATE=${INPROGRESS}
    while [[ "$INPROGRESS" != "READY" ]]
    do      
            INPROGRESS=$(get_sddc_status "${NAME_LOWER}" "${PASSWORD}")
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

get_personalities_full(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/personalities)
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

get_domain_validation_status(){
	VALIDATIONID="${1}"
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/domains/validations/${VALIDATIONID})
	echo "${VALIDATIONRESULT}" > /tmp/scripts/domain-validation-test.json
	echo "${VALIDATIONRESULT}"
}


get_hosts_validation_status(){
	VALIDATIONID="${1}"
	VALIDATIONRESULT=$(curl -s -k -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" -X GET  https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts/validations/${VALIDATIONID})
	echo "${VALIDATIONRESULT}" > /tmp/scripts/hosts-validation-test.json
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

post_domain_validation() {
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

post_domain_creation() {
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


loop_wait_domain_validation(){
    VALIDATIONID="${1}"
    RESPONSE=$(get_domain_validation_status "${VALIDATIONID}")
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
        RESPONSE=$(get_domain_validation_status "${VALIDATIONID}")
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
    RESPONSE=$(get_domain_validation_status "${VALIDATIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.resultStatus')

    echo
    echo "Host Validation Result Status : $RESULTSTATUS"

    if [ "${RESULTSTATUS}" != "SUCCEEDED" ]
    then
        echo "Domain Validation not succesful. Quitting"
        exit
    fi

}

loop_wait_hosts_validation(){
    VALIDATIONID="${1}"
    # RESPONSE=$(get_hosts_validation_status "${VALIDATIONID}")
    # if [[ "${RESPONSE}" == *"ERROR - HTTPSTATUS"* ]] || [[ "${RESPONSE}" == "" ]]
    # then
    #     echo "problem getting initial validation ${VALIDATIONID} status : "
    #     echo "${RESPONSE}"
    # else
    #     STATUS=$(echo "${RESPONSE}" | jq -r '.executionStatus')
    #     echo "${STATUS}"
    # fi

    CURRENTSTATE=""
    CURRENTSTEP=""
    CURRENTMAINTASK=""
    EXECUTIONSTATUS=""
    RESULTSTATUS=""
    while [[ "$EXECUTIONSTATUS" != "COMPLETED" ]]
    do      
        RESPONSE=$(get_hosts_validation_status "${VALIDATIONID}")
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
    RESPONSE=$(get_hosts_validation_status "${VALIDATIONID}")
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
    TOKENTIMER=0
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
        TOKENTIMER=$((TOKENTIMER+1))
        if [[ $TOKENTIMER -gt 150 ]]
        then
            TOKEN=$(get_sddc_token "${NAME_LOWER}" "${PASSWORD}" )
        fi
        sleep 2
    done
    RESPONSE=$(get_commission_status "${COMMISSIONID}")
    RESULTSTATUS=$(echo "${RESPONSE}" | jq -r '.status')
    echo
    echo "Commisioning Result Status : $RESULTSTATUS"    
}

###################