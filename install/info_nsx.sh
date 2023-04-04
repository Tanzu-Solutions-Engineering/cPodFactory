#!/bin/bash
#edewitte@vmware.com

source  ./env
source ./env.passwd

if [ ${BACKEND_NETWORK} != "NSX-T" ]; then
    echo "This cPodFactory does not use NSX-T"
    exit 
fi

# ===== Login with basic auth =====
RESPONSE=$(curl -vvv -k -c /tmp/session.txt -X POST -d 'j_username='${NSX_ADMIN}'&j_password='${NSX_PASSWD}'' https://${NSX}/api/session/create 2>&1 > /dev/null | grep XSRF)
XSRF=$(echo $RESPONSE | awk '{print $3}')
JSESSIONID=$(cat /tmp/session.txt | grep JSESSIONID | rev | awk '{print $1}' | rev)

# ===== checking nsx version =====
echo "Checking nsx version"

RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}" https://${NSX}/api/v1/node/version)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        VERSIONINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        PRODUCTVERSION=$(echo $VERSIONINFO |jq .product_version)
        echo "  Product: ${PRODUCTVERSION}"
else
        echo "  error getting version"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== checking user admin =====
echo "Checking user Admin"
RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}" https://${NSX}/api/v1/node/users)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        USERINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')

        echo $USERINFO | jq -r '["NAME","STATUS","PWD Freq","ID"], ["----","------","--------","--"], (.results[] | [.username, .status, .password_change_frequency, .userid]) | @tsv' | column -t -s $'\t'

        COUNTOFRISKS=$(echo $USERINFO |jq '.results[] | select (.password_change_frequency <100)| .userid' | wc -l)
        if [[ $COUNTOFRISKS > 0 ]]; then 
                echo "Set users with pwd freq <100 (yes or no) ? "
                read answer
                if [[ $answer == "yes" ]]; then
                        SHORTPWDUSERS=$(echo $USERINFO | jq '.results[] | select (.password_change_frequency <100)| .userid')
                        for USERID in $SHORTPWDUSERS; do
                                #echo "curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H \"X-XSRF-TOKEN: ${XSRF}\" --data-binary '{ \"password_change_frequency\": 9999 }' https://${NSX}/api/v1/node/users/${USERID}"
                                RESPONSE=$(curl -s -k -w '####%{response_code}' -b /tmp/session.txt -H "X-XSRF-TOKEN: ${XSRF}"  -X PUT -H 'Content-Type: application/json' --data-binary '{ "password_change_frequency": 9999 }' https://${NSX}/api/v1/node/users/${USERID})
                                HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
                                if [ $HTTPSTATUS -eq 200 ]
                                then
                                        echo "success for ${USERID}"
                                else
                                        echo "error setting user ${USERID}"
                                        echo ${HTTPSTATUS}
                                        echo ${RESPONSE}
                                        exit
                                fi
                        done
                else
                        echo "you didn't chose 'yes'"
                fi
        else
                echo
                echo "No issues identified that require fixing"

        fi
else
        echo "error getting users"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi
 