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
        else
                echo "error logging in"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_cluster_info(){
        # get Cluster Version
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/cluster   -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo "Response : "
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
                echo "Response : "
                echo ${RESPONSEJSON} |jq .
                CLOUD_UUID=$(echo ${RESPONSEJSON} |jq -r '.results[] | select ( .vtype = "CLOUD_NONE") | .uuid' )
                echo "${CLOUD_UUID}"
        else
                echo "error logging in"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}
###################