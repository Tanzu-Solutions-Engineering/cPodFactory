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



# ===== login =====
echo "trying to login"
RESPONSE=$(curl -s -k -w '####%{response_code}'  -H "Content-Type: application/json" -d '{"username":"admin", "password":"58NFaGDJm(PJH0G"}'  -X POST   https://${NSXALBFQDN}/login  --cookie-jar /tmp/cookies.txt)
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

# ===== Setting hearders =====

AVIVERSION=$(echo $SYSTEMINFO | jq .version.Version)
CSRFTOKEN=$(cat /tmp/cookies.txt |grep csrftoken | awk -F 'csrftoken' '{print $2}'  |tr -d '[:space:]')
declare -a curlArgs=('-H' "Content-Type: application/json")
curlArgs+=('-H' "Accept":"application/json")
#curlArgs+=('-H' "x-avi-version":"${AVIVERSION}")
curlArgs+=('-H' "x-avi-version":"${AVIVERSIONAPI}")
curlArgs+=('-H' "x-csrftoken":"${CSRFTOKEN}")
curlArgs+=('-H' "referer":"https://${NSXALBFQDN}/login")


# ===== Changing configuration =====

echo "Getting System Configuration"
RESPONSE=$(curl -s -k -w '####%{response_code}' https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Configuring Basic Authentication"
else
        echo "error getting system config"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

echo "Setting System Configuration : enabling Basic Auth"
SYSTEMCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
NEWSYSTEMCONFIG=$(echo ${SYSTEMCONFIG} | jq '.portal_configuration.allow_basic_authentication = true' | jq 'del(.secure_channel_configuration.bypass_secure_channel_must_checks)')
RESPONSE=$(curl -s -k -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $NEWSYSTEMCONFIG)" https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Basic Auth set successfully"
else
        echo "error getting system config"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Set Admin password =====

EXISTINGPWD=$(echo "admin:58NFaGDJm(PJH0G" | base64)

CSRFTOKEN=$(cat /tmp/cookies.txt |grep csrftoken | awk -F 'csrftoken' '{print $2}'  |tr -d '[:space:]')
declare -a curlArgs=('-H' "Content-Type: application/json")
curlArgs+=('-H' "Accept":"application/json")
curlArgs+=('-H' "x-avi-version":"${AVIVERSIONAPI}")
curlArgs+=('-H' "x-csrftoken":"${CSRFTOKEN}")
curlArgs+=('-H' "referer":"https://${NSXALBFQDN}/login")

bodyArgs='{"old_password":"58NFaGDJm(PJH0G", "password":"'${PASSWORD}'", "username":"admin"}'

echo "Setting new password"
RESPONSE=$(curl -s -k  -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $bodyArgs)" https://${NSXALBFQDN}/api/useraccount -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Password Changed"
        echo ${RESPONSE} |awk -F '####' '{print $1}'
else
        echo "error changing password"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Login with basic auth =====
echo "trying to login with new password "
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

# ===== Getting backup passphrase auth =====
echo "trying to login with new password "
CSRFTOKEN=$(cat /tmp/cookies.txt |grep csrftoken | awk -F 'csrftoken' '{print $2}'  |tr -d '[:space:]')
declare -a curlArgs=('-H' "Content-Type: application/json")
curlArgs+=('-H' "Accept":"application/json")
#curlArgs+=('-H' "x-avi-version":"${AVIVERSION}")
curlArgs+=('-H' "x-avi-version":"${AVIVERSIONAPI}")
curlArgs+=('-H' "x-csrftoken":"${CSRFTOKEN}")
curlArgs+=('-H' "referer":"https://${NSXALBFQDN}/login")

RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X GET https://${NSXALBFQDN}/api/backupconfiguration   -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        echo "Got config data - setting passphrase"
else
        echo "error logging in"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

BAKCUPUUID=$(echo $RESPONSE |awk -F '####' '{print $1}' | jq .results[0].uuid | tr -d '"')
BACKUPJSON=$(echo $RESPONSE |awk -F '####' '{print $1}' | jq '.results[0] += {"backup_passphrase":"'${PASSWORD}'"}' | jq .results[0])
ADDJSON='{ "replace": '${BACKUPJSON}' }'

RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X PATCH https://${NSXALBFQDN}/api/backupconfiguration/${BAKCUPUUID} -d "$(echo ${ADDJSON})"  -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Passphrase set"
else
        echo "error setting passphrase"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Setting DNS / SMTP =====
echo "Getting Configuration settings"

RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Got config data"
else
        echo "error getting config data"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

echo "Setting Configuration settings : DNS / STMP"
SYSTEMCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
NEWSYSTEMCONFIG=$(echo ${SYSTEMCONFIG} | jq '.dns_configuration.search_domain = "'${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'"')
NEWSYSTEMCONFIG=$(echo ${NEWSYSTEMCONFIG} | jq '.email_configuration.smtp_type = "SMTP_NONE"')
NEWSYSTEMCONFIG=$(echo ${NEWSYSTEMCONFIG} | jq '.dns_configuration += {"server_list"}' | jq '.dns_configuration.server_list += [{"addr":"'${GATEWAY}'","type":"V4"}]')

RESPONSE=$(curl -s -k -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $NEWSYSTEMCONFIG)" https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "DNS/SMTP set"
else
        echo "error setting DNS/SMTP"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Setting Welcome workflow =====
echo "Getting Configuration settings"

RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Got config data"
else
        echo "error getting config data"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

echo "Setting Configuration settings : Welcome workflow complete"
SYSTEMCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
NEWSYSTEMCONFIG=$(echo ${SYSTEMCONFIG} | jq '.welcome_workflow_complete = true')

RESPONSE=$(curl -s -k -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $NEWSYSTEMCONFIG)" https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Welcome workflow set to completed"
else
        echo "error setting Welcome workflow"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


# ===== Setting Licensing Tier to Enterprise =====
echo "Getting Configuration settings"

RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Got config data"
else
        echo "error getting config data"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

echo "Setting Configuration settings : Licensing Tier"
SYSTEMCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
NEWSYSTEMCONFIG=$(echo ${SYSTEMCONFIG} | jq '.default_license_tier = "ENTERPRISE"')

RESPONSE=$(curl -s -k -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $NEWSYSTEMCONFIG)" https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Welcome workflow set to completed"
else
        echo "error setting Welcome workflow"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Create Self signed certs =====

# Self-Sign TLS Certificate json
NSXAdvLBSSLCertEmail="admin@${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
SSLJSONPAYLOAD=$(cat ./extra/nsxalb-ssl-cert-template.json)
SSLJSONPAYLOAD=$(echo ${SSLJSONPAYLOAD} | jq '.certificate.subject.common_name = "'${NSXALBFQDN}'"')
SSLJSONPAYLOAD=$(echo ${SSLJSONPAYLOAD} | jq '.certificate.subject.email_address = "'${NSXAdvLBSSLCertEmail}'"')
SSLJSONPAYLOAD=$(echo ${SSLJSONPAYLOAD} | jq '.certificate.subject_alt_names += ["'${IP}'"]')
SSLJSONPAYLOAD=$(echo ${SSLJSONPAYLOAD} | jq '.certificate.subject_alt_names += ["'${NSXALBFQDN}'"]')

RESPONSE=$(curl -s -k -w '####%{response_code}' -X POST "${curlArgs[@]}" -d "$(echo ${SSLJSONPAYLOAD})" https://${NSXALBFQDN}/api/sslkeyandcertificate -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 201 ]
then
        echo "Self Signed certificate created"
else
        echo "error creating self signed cert"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi
CERTURL=$(echo $RESPONSE |awk -F '####' '{print $1}' | jq .url)

# ===== Changing configuration =====

echo "Getting System Configuration"
RESPONSE=$(curl -s -k -w '####%{response_code}' https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Configuring Basic Authentication"
else
        echo "error getting system config"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

echo "Setting System Configuration : enabling Basic Auth"
SYSTEMCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')

NEWSYSTEMCONFIG=$(echo ${SYSTEMCONFIG} | jq 'del(.secure_channel_configuration.bypass_secure_channel_must_checks)'| jq '.portal_configuration.sslkeyandcertificate_refs = ['${CERTURL}']')

RESPONSE=$(curl -s -k -w '####%{response_code}' -X PUT "${curlArgs[@]}" -d "$(echo $NEWSYSTEMCONFIG)" https://${NSXALBFQDN}/api/systemconfiguration -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Changed self sign cert portal assignment"
else
        echo "error Changing self sign cert portal assignment"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== Cloud Configuration : vCenter =====

echo "Getting Cloud Configuration"
RESPONSE=$(curl -s -k -w '####%{response_code}' https://${NSXALBFQDN}/api/cloud -b /tmp/cookies.txt)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
if [ $HTTPSTATUS -eq 200 ]
then
        echo "Configuring Basic Authentication"
else
        echo "error getting system config"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

CLOUDCONFIG=$(echo ${RESPONSE} |awk -F '####' '{print $1}')


# ===== Script finished =====
echo "Configuration done"

