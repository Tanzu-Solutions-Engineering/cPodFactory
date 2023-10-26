#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name> <owner email>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi


### Local vars ####

AVIVERSIONAPI="20.1.4"

HOSTNAME=${HOSTNAME_NSXALB}
FQDN=${HOSTNAME_NSXALB}.${DOMAIN}
IP=${IP_NSXALBMGR}
OVA=${NSXALBOVA}

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

[ "${HOSTNAME_NSXALB}" == ""  -o "${NSXALBOVA}" == "" -o "${IP_NSXALBMGR}" == "" ] && echo "missing parameters - please source version file !" && exit 1

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
VMNAME="${VAPP}-${HOSTNAME}"

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# ===== Start of code =====

NSXALBFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}

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
                        ;;
                301)
                        echo "switching to https portal"
                        STATUS="SUCCEEDED"
                        ;;
                *)
                        echo "status: $HTTPSTATUS"
                        ;;
        esac
        sleep 5
done	

# ===== Login with basic auth =====
echo "trying to login with cpod password"
RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Content-Type: application/json" -d '{"username":"admin", "password":"'${PASSWORD}'"}'  -X POST   https://${NSXALBFQDN}/login  --cookie-jar /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        echo "logged in"
        SYSTEMINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
else
        echo "error logging in"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== setting args =====
echo "building curl args "
CSRFTOKEN=$(cat /tmp/cookies.txt |grep csrftoken | awk -F 'csrftoken' '{print $2}'  |tr -d '[:space:]')
declare -a curlArgs=('-H' "Content-Type: application/json")
curlArgs+=('-H' "Accept":"application/json")
curlArgs+=('-H' "x-avi-version":"${AVIVERSIONAPI}")
curlArgs+=('-H' "x-csrftoken":"${CSRFTOKEN}")
curlArgs+=('-H' "referer":"https://${NSXALBFQDN}/login")

# API calls
# gettign clusterUUID
RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/cluster   -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        echo "Response : "
        echo ${RESPONSE} |awk -F '####' '{print $1}' |jq .
else
        echo "error logging in"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


# API calls
# gettign clusterUUID
RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/cloud   -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        echo "Response : "
        echo ${RESPONSE} |awk -F '####' '{print $1}' |jq .
else
        echo "error logging in"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


exit
# getting SEOVA

echo "Getting Configuration settings"
CLOUDUUID=""
RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/securetoken-generate?cloud_uuid=${CLOUDUUID} -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Got config data"
        echo ${RESPONSE} |awk -F '####' '{print $1}' |jq .
else
        echo "error getting config data"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Script finished =====
echo "Configuration done"


curl 'https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/securetoken-generate?cloud_uuid=cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/' -H 'X-Avi-UserAgent: UI' -H 'X-Avi-Version: 22.1.4' -H 'X-Avi-Tenant: admin' -H 'X-CSRFToken: OcwCkDW9d2EKYV5CDraMzMQPEglXZogl' -H 'Connection: keep-alive' -H 'Cookie: csrftoken=OcwCkDW9d2EKYV5CDraMzMQPEglXZogl; avi-sessionid=gzr0mj3sof713w00zhuh55t6kdkefxj4; sessionid=gzr0mj3sof713w00zhuh55t6kdkefxj4' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers'
