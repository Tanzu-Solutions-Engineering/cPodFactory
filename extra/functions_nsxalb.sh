#!/bin/bash
#edewitte@vmware.com

### NSX ALB functions ####

# ========== NSX ALB functions ===========

AVIVERSIONAPI="22.1.4"

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
        else
                echo "error logging in"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_cluster_info(){
        # get Cluster info json
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/cluster   -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                #echo "Response : "
                echo ${RESPONSE} |awk -F '####' '{print $1}' |jq .
        else
                echo "error getting cluster info"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_cluster_uuid(){
        # get clusterUUID
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/cloud   -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "Response : "
                #echo ${RESPONSEJSON} |jq .
                CLOUD_UUID=$(echo ${RESPONSEJSON} |jq -r '.results[] | select ( .vtype = "CLOUD_NONE") | .uuid' )
                echo "${CLOUD_UUID}"
        else
                echo "error getting cluster uuid"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

vcenter_verify_login(){
        # curl 'https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/vimgrvcenterruntime/verify/login' -X POST -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/' -H 'X-Avi-UserAgent: UI' -H 'X-Avi-Version: 22.1.4' -H 'X-Avi-Tenant: admin' -H 'Content-Type: application/json;charset=utf-8' -H 'X-CSRFToken: Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm' -H 'Origin: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net' -H 'Connection: keep-alive' -H 'Cookie: csrftoken=Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm; avi-sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az; sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers' 
        #       --data-raw '{"username":"administrator@cpod-v8alb.az-lhr.cloud-garage.net","password":"NlPlnFh1vbF!","host":"vcsa.cpod-v8alb.az-lhr.cloud-garage.net"}'
        USERNAME=${1}
        PASSWORD=${2}
        VCENTER_FQDN=${3}
        DATA='{"username":"'${USERNAME}'","password":"'${PASSWORD}'","host":"'${VCENTER_FQDN}'"}'
        SCRIPT="/tmp/DATA-$$"
        echo ${DATA} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X POST -d @${SCRIPT} https://${NSXALBFQDN}/api/vimgrvcenterruntime/verify/login -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "Response : "
                echo ${RESPONSEJSON} |jq .
        else
                echo "error verifying vcenter login"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}
###################