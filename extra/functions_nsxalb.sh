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
                export API_MIN_VERSION=$(echo "${SYSTEMINFO}" | jq .version.min_version)
                export CLUSTER_API_VERSION=$(echo "${SYSTEMINFO}" | jq .version.Version)
        else
                echo "error logging in"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_cluster_info(){
        # get Cluster info json
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/cluster   -b /tmp/cookies.txt)
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
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X GET https://${NSXALBFQDN}/api/cloud   -b /tmp/cookies.txt)
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
#        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -d '{"username":"admin", "password":"'${PASSWORD}'"}' -X POST -d @${SCRIPT} https://${NSXALBFQDN}/api/vimgrvcenterruntime/verify/login -b /tmp/cookies.txt)
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X POST -d @${SCRIPT} https://${NSXALBFQDN}/api/vimgrvcenterruntime/verify/login -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "Response : "
                echo ${RESPONSEJSON} |jq -r .resource.vcenter_dc_info[].name
        else
                echo "error verifying vcenter login"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

configure_defaultcloud_vcenter(){

# curl 'https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/cloud/cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea?include_name' -X PUT -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/' -H 'X-Avi-UserAgent: UI' -H 'X-Avi-Version: 22.1.4' -H 'X-Avi-Tenant: admin' -H 'Content-Type: application/json;charset=utf-8' -H 'X-CSRFToken: Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm' -H 'Origin: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net' -H 'Connection: keep-alive' -H 'Cookie: csrftoken=Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm; avi-sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az; sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers' 
#       --data-raw '{"url":"https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/cloud/cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea#Default-Cloud","uuid":"cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea","name":"Default-Cloud","tenant_ref":"https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/tenant/admin#admin","_last_modified":"1698323383028197","autoscale_polling_interval":60,"dhcp_enabled":false,"dns_resolution_on_se":false,"enable_vip_on_all_interfaces":false,"enable_vip_static_routes":false,"ip6_autocfg_enabled":false,"maintenance_mode":false,"metrics_polling_interval":300,"mtu":1500,"prefer_static_routes":false,"state_based_dns_registration":true,"vmc_deployment":false,"vtype":"CLOUD_VCENTER","vcenter_configuration":{"privilege":"WRITE_ACCESS","use_content_lib":false,"is_nsx_environment":false,"datacenter":"cPod-V8ALB","vcenter_url":"vcsa.cpod-v8alb.az-lhr.cloud-garage.net","username":"administrator@cpod-v8alb.az-lhr.cloud-garage.net","password":"NlPlnFh1vbF!"}}'
        CLOUDUUID=${1}
        USERNAME=${2}
        PASSWORD=${3}
        VCENTER_FQDN=${4}
        DATACENTER=${5}

        DATA='{"url":"https://'"${NSXALBFQDN}"'/api/cloud/'"${CLOUDUUID}"'#Default-Cloud","uuid":"'"${CLOUDUUID}"'","name":"Default-Cloud",
        "tenant_ref":"https://'"${NSXALBFQDN}"'/api/tenant/admin#admin","autoscale_polling_interval":60,"dhcp_enabled":false,"dns_resolution_on_se":false,
        "enable_vip_on_all_interfaces":false,"enable_vip_static_routes":false,"ip6_autocfg_enabled":false,"maintenance_mode":false,
        "metrics_polling_interval":300,"mtu":1500,"prefer_static_routes":false,"state_based_dns_registration":true,"vmc_deployment":false,
        "vtype":"CLOUD_VCENTER","vcenter_configuration":{"privilege":"WRITE_ACCESS","use_content_lib":false,"is_nsx_environment":false,
        "datacenter":"'"${DATACENTER}"'","vcenter_url":"'"${VCENTER_FQDN}"'",
        "username":"'"${USERNAME}"'","password":"'"${PASSWORD}"'"}}'
        SCRIPT="/tmp/DATA-$$"
        echo ${DATA} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X PUT -d @${SCRIPT} https://${NSXALBFQDN}/api/cloud/"${CLOUDUUID}"?include_name -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "Response : "
                echo ${RESPONSEJSON} |jq .
        else
                echo "error configuring default cloud vcenter"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_portgroups(){
        # curl 'https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/vimgrvcenterruntime/retrieve/portgroups?page_size=200' -X POST -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/' -H 'X-Avi-UserAgent: UI' -H 'X-Avi-Version: 22.1.4' -H 'X-Avi-Tenant: admin' -H 'Content-Type: application/json;charset=utf-8' -H 'X-CSRFToken: Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm' -H 'Origin: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net' -H 'Connection: keep-alive' -H 'Cookie: csrftoken=Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm; avi-sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az; sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers'
        # --data-raw '{"cloud_uuid":"cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea"}'
        CLOUDUUID=${1}

        DATA='{"cloud_uuid":"'"${CLOUDUUID}"'"}'
        SCRIPT="/tmp/DATA-$$"
        echo ${DATA} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" -X POST -d @${SCRIPT} https://${NSXALBFQDN}/api/vimgrvcenterruntime/retrieve/portgroups -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "Response : "
                echo ${RESPONSEJSON} |jq .
        else
                echo "error getting portgroups"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_portgroup_info(){
        # curl 'https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/api/network/dvportgroup-23-cloud-89a795f5-52e1-4d23-8184-6e9c992d0aea?include_name=true' -H 'User-Agent: Mozilla/5.0 (Macintosh; Intel Mac OS X 10.15; rv:109.0) Gecko/20100101 Firefox/118.0' -H 'Accept: application/json, text/plain, */*' -H 'Accept-Language: en-US,en;q=0.5' -H 'Accept-Encoding: gzip, deflate, br' -H 'Referer: https://nsxalb01.cpod-v8alb.az-lhr.cloud-garage.net/' -H 'X-Avi-UserAgent: UI' -H 'X-Avi-Version: 22.1.4' -H 'X-Avi-Tenant: admin' -H 'X-CSRFToken: Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm' -H 'Connection: keep-alive' -H 'Cookie: csrftoken=Ix4pDXABLlZcjkNr3NmkHEKWwAIQoRJm; avi-sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az; sessionid=moanoz5jflrgs1cfpzi73puhy03wc8az' -H 'Sec-Fetch-Dest: empty' -H 'Sec-Fetch-Mode: cors' -H 'Sec-Fetch-Site: same-origin' -H 'TE: trailers'

        PORTGROUPUUID=${1}

        RESPONSE=$(curl -s -k -w '####%{response_code}' "${curlArgs[@]}" https://${NSXALBFQDN}/api/network/${PORTGROUPUUID} -b /tmp/cookies.txt)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                RESPONSEJSON=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo "Response : "
                echo ${RESPONSEJSON} |jq .
        else
                echo "error getting portgroups"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}





###################