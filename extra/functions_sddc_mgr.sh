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

get_hosts(){
    NAME_LOWER="${1}"
    TOKEN="${2}"
    SDDCHOSTS=$(curl -s -k -X GET -H "Content-Type: application/json" -H "Authorization: Bearer ${TOKEN}" https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/v1/hosts | jq .elements[].fqdn)
    echo "$SDDCHOSTS"
}

###################