#!/bin/bash
#edewitte@vmware.com

### NSX ALB functions ####


# ========== NSX ALB functions ===========

AVIVERSIONAPI="20.1.4"

Check_NSXALB_Online(){
        # needs NSXALBFQDN
        echo "Querying status"

        STATUS="RUNNING"
        while [ "${STATUS}" != "SUCCEEDED" ]
        do
                echo "connecting..."
                RESPONSE=$(curl -s -w '####%{response_code}' http://${NSXALBFQDN})
                HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
                case $HTTPSTATUS in
                        000)
                                echo "000"
                                sleep 5
                                ;;
                        301)
                                echo "switching to https portal"
                                STATUS="SUCCEEDED"
                                ;;
                        *)
                                echo "status: $HTTPSTATUS"
                                sleep 5
                                ;;
                esac
        done	
}

login_nsxalb() {
        # needs NSXALBFQDN
        # needs PASSWORD
        RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Content-Type: application/json" -d '{"username":"admin", "password":"'${PASSWORD}'"}'  -X POST   https://${NSXALBFQDN}/login  --cookie-jar /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo "logged in"
                SYSTEMINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "System info :"
                #echo "${SYSTEMINFO}" | jq .
                API_MIN_VERSION=$(echo "${SYSTEMINFO}" | jq .version.min_version)
                CLUSTER_API_VERSION=$(echo "${SYSTEMINFO}" | jq .version.Version)
#                echo "building curl args "
#                CSRFTOKEN=$(cat /tmp/cookies.txt |grep csrftoken | awk -F 'csrftoken' '{print $2}'  |tr -d '[:space:]')
#                declare -a -x curlArgs=('-H' "Content-Type: application/json")
#                curlArgs+=('-H' "Accept":"application/json")
#                curlArgs+=('-H' "x-avi-version":"${AVIVERSIONAPI}")
#                curlArgs+=('-H' "x-csrftoken":"${CSRFTOKEN}")
#                curlArgs+=('-H' "referer":"https://${NSXALBFQDN}/login")
#                
        else
                echo "error logging in"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}


###################