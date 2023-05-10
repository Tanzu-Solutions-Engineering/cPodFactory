#!/bin/bash
#edewitte@vmware.com

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

HOSTNAME=${HOSTNAME_NSX}
NAME=${NAME_NSX}
IP=${IP_NSXMGR}
OVA=${OVA_NSXMGR}

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################


if [ ! -f ./licenses.key ]; then
	echo "./licenses.key does not exist. please create one by using the licenses.key.template as reference"
	exit
else
	source ./licenses.key
fi

[ "${LIC_NSXT}" == ""  -o "${LIC_NSXT}" == "XXXXX-XXXXX-XXXXX-XXXXX-XXXXX" ] && echo "LIC_NSXT not set - please check licenses.key file !" && exit 1

[ "${HOSTNAME}" == ""  -o "${IP}" == "" ] && echo "missing parameters - please source version file !" && exit 1

### functions ####

source ./extra/functions.sh

# ========== NSX functions ===========

get_compute_manager() {
        # $1 = compute manager name
        # returns json
        MGRNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${MANAGERSINFO}" > /tmp/mgr_json
                MANAGERSCOUNT=$(echo $MANAGERSINFO | jq .result_count)
                if [[ ${MANAGERSCOUNT} -gt 0 ]]
                then
                        EXISTINGMNGR=$(echo "${MANAGERSINFO}" | jq -r '.results[] | select (.server == "'${MGRNAME}'") | .server')
                        if [[ "${EXISTINGMNGR}" == "${MGRNAME}" ]]
                        then
                                echo "  existing manager set to : ${EXISTINGMNGR}"
                                MGRID=$(echo "${MANAGERSINFO}" | jq -r '.results[] | select (.server == "'${MGRNAME}'") | .id')
                                echo "  Manager id : ${MGRID}"
                        else
                                echo "  ${EXISTINGMNGR} does not match ${MGRNAME}"
                        fi
                else
                        echo ""
                fi
        else
                echo "  error getting managers"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_compute_manager_id() {
        # $1 = compute manager name
        # returns json
        MGRNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${MANAGERSINFO}" > /tmp/mgrid_json
                MANAGERSCOUNT=$(echo $MANAGERSINFO | jq .result_count)
                if [[ ${MANAGERSCOUNT} -gt 0 ]]
                then
                        EXISTINGMNGR=$(echo "${MANAGERSINFO}" | jq -r '.results[] | select (.server == "'${MGRNAME}'") | .server')
                        if [[ "${EXISTINGMNGR}" == "${MGRNAME}" ]]
                        then
                                MGRID=$(echo "${MANAGERSINFO}" | jq -r '.results[] | select (.server == "'${MGRNAME}'") | .id')
                                echo "${MGRID}"
                        else
                                echo ""
                        fi
                else
                        echo ""
                fi
        else
                echo "  error getting managers id"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

nsx_accept_eula() {
        #
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X POST https://${NSXFQDN}/policy/api/v1/eula/accept)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo "  EULA accepted succesfully "
        else
                echo "  error accepting eula"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

nsx_ceip_agreement() {
        #
        CEIP_JSON='{
        "_revision": 1,
        "id": "TelemetryAgreementIdentifier",
        "resource_type": "TelemetryAgreement",
        "telemetry_agreement_displayed": true
        }'
        SCRIPT="/tmp/CEIP_JSON"
        echo ${CEIP_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/telemetry/agreement)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo "  ceip agreement set "
        else
                echo "  error setting ceip agreement"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

nsx_ceip_telemetry() {
        #

        CEIP_JSON='{"ceip_acceptance" : false, "schedule_enabled": true, "_revision" : 0}'
        SCRIPT="/tmp/CEIP_JSON"
        echo ${CEIP_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/telemetry/config)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo "  ceip telemetry set "
        else
                echo "  error setting ceip telemetry"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

add_computer_manager() {
        #$1 Compute Manager fqdn
        MGRFQDN=$1
        CM_JSON='{
        "server": "'"${MGRFQDN}"'",
        "display_name": "'"${MGRFQDN}"'",
        "origin_type": "vCenter",
        "credential" : {
        "credential_type" : "UsernamePasswordLoginCredential",
        "username": "administrator@'${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
        "password": "'${PASSWORD}'",
        "thumbprint": "'${VCENTERTP}'"
        }
        }'
        SCRIPT="/tmp/CM_JSON"
        echo ${CM_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/fabric/compute-managers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 201 ]
        then
                MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${MANAGERSINFO}" > /tmp/mgradd_json
                MANAGERSRV=$(echo $MANAGERSINFO | jq -r .server)
                echo "  Compute Manager added succesfully = ${MANAGERSRV}"
        else
                echo "  error setting manager"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_compute_manager_status() {
        #$1 Compute Mgr ID      
        #returns json

        MGRID=$1
 
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers/${MGRID}/status)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                MGRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $MGRINFO > /tmp/mgrstatus-json 
                if [[ "${MGRINFO}" != "" ]]
                then
                        echo "${MGRINFO}" #| jq -r '[.registration_status, .connection_status] |@tsv'
                fi
        else
                echo "  error getting compute manager status"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

loop_wait_compute_manager_status(){
        #$1 = Compute Mgr ID
        MGRID=$1
        echo "  Checking compute manager status"
        echo
        MGRSTATUS=$(get_compute_manager_status "${MGRID}")
        #echo "${MGRSTATUS}"
        INPROGRESS=$(echo "${MGRSTATUS}" | jq -r .connection_status)
        while [[ "$INPROGRESS" != "UP" ]]
        do
                echo "${MGRSTATUS}"
                echo 
                sleep 10
                MGRSTATUS=$(get_compute_manager_status "${MGRID}")
                INPROGRESS=$(echo "${MGRSTATUS}" | jq .connection_status)
        done

}

add_nsx_license() {
        LIC_JSON='{ "license_key": "'${LIC_NSXT}'" }'
        SCRIPT="/tmp/LIC_JSON"
        echo ${LIC_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/licenses)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LICINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo ${LICINFO}
                echo "License added succesfully"
        else
                echo "  error adding license"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

check_uplink_profile() {
        #$1 profile name string
        #returns json
        PROFILENAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #echo ${PROFILESINFO}
                #PROFILESCOUNT=$(echo ${PROFILESINFO} | jq .result_count)
                #echo ${PROFILESCOUNT}
                echo $PROFILESINFO |jq '.results[] | select (.display_name =="'$PROFILENAME'")'
        else
                echo "  error getting uplink profiles"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_uplink_profile_id() {
        #$1 profile name string
        #returns json
        PROFILENAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${PROFILESINFO}" > /tmp/profile-json
                echo $PROFILESINFO |jq -r '.results[] | select (.display_name =="'$PROFILENAME'") | .id'
        else
                echo "  error getting uplink profiles"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_uplink_profile_uniqueid() {
        #$1 profile name string
        #returns json
        PROFILENAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${PROFILESINFO}" > /tmp/profile-json
                echo $PROFILESINFO |jq -r '.results[] | select (.display_name =="'$PROFILENAME'") | .unique_id'
        else
                echo "  error getting uplink profiles"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_uplink_profile_path() {
        #$1 profile name string
        #returns json
        PROFILENAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${PROFILESINFO}" > /tmp/profile-json
                echo $PROFILESINFO |jq -r '.results[] | select (.display_name =="'$PROFILENAME'") | .path'
        else
                echo "  error getting uplink profiles"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

create_uplink_profile() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        PROFILENAME=$1
        VLANID=$2

        PROFILE_JSON='{
        "teaming": {
        "policy": "LOADBALANCE_SRCID",
        "active_list": [
        {
                "uplink_name": "uplink-1",
                "uplink_type": "PNIC"
        },
        {
                "uplink_name": "uplink-2",
                "uplink_type": "PNIC"
        }
        ],
        "rolling_order": false
        },
        "named_teamings": [
        {
        "name": "'$PROFILENAME'-uplink-2",
        "policy": "FAILOVER_ORDER",
        "active_list": [
                {
                "uplink_name": "uplink-2",
                "uplink_type": "PNIC"
                }
        ],
        "rolling_order": false
        },
        {
        "name": "'$PROFILENAME'-uplink-1",
        "policy": "FAILOVER_ORDER",
        "active_list": [
                {
                "uplink_name": "uplink-1",
                "uplink_type": "PNIC"
                }
        ],
        "rolling_order": false
        }
        ],
        "transport_vlan": '$VLANID',
        "overlay_encap": "GENEVE",
        "resource_type": "PolicyUplinkHostSwitchProfile",
        "display_name": "'$PROFILENAME'"
        }'

        SCRIPT="/tmp/PROFILE_JSON"
        echo ${PROFILE_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/host-switch-profiles/${PROFILENAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${PROFILENAME} created succesfully"
                #echo ${PROFILESINFO}
        else
                echo "  error creating uplink profile : ${PROFILENAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

check_transport_zone() {
        #$1 transport zone name string
        #returns json
        TZNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #TZCOUNT=$(echo ${TZINFO} | jq .result_count)           
                echo "${TZINFO}" > /tmp/tz-json
                echo $TZINFO |jq '.results[] | select (.display_name =="'$TZNAME'")'
        else
                echo "  error getting transport zones"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_transport_zone_id() {
        #$1 transport zone name string
        #returns json
        TZNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #TZCOUNT=$(echo ${TZINFO} | jq .result_count)                
                echo $TZINFO |jq -r '.results[] | select (.display_name =="'$TZNAME'") | .id'
        else
                echo "  error getting transport zones"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_transport_zone_uniqueid() {
        #$1 transport zone name string
        #returns json
        TZNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #TZCOUNT=$(echo ${TZINFO} | jq .result_count)                
                echo $TZINFO |jq -r '.results[] | select (.display_name =="'$TZNAME'") | .unique_id'
        else
                echo "  error getting transport zones"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_transport_zone_path() {
        #$1 transport zone name string
        #returns json
        TZNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                #TZCOUNT=$(echo ${TZINFO} | jq .result_count)                
                echo $TZINFO |jq -r '.results[] | select (.display_name =="'$TZNAME'") | .path'
        else
                echo "  error getting transport zones"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

create_transport_zone() {
        #$1 transport zone string
        #$2 tz_type (OVERLAY_STANDARD, VLAN_BACKED )
        #$3 uplink names (i.e. : edge-uplink)
        #returns json
        TZNAME=$1
        TZTYPE=$2
        UPLINKNAME=$3
        if [ "${UPLINKNAME}" == "" ]
        then
                TZ_JSON='{
                "tz_type": "'${TZTYPE}'",
                "is_default": false,
                "nested_nsx": false,
                "resource_type": "PolicyTransportZone",
                "display_name": "'${TZNAME}'"
                }'

        else
                TZ_JSON='{
                "tz_type": "'${TZTYPE}'",
                "is_default": false,
                "uplink_teaming_policy_names": [
                "'${UPLINKNAME}'-uplink-1",
                "'${UPLINKNAME}'-uplink-2"
                ],
                "nested_nsx": true,
                "resource_type": "PolicyTransportZone",
                "display_name": "'${TZNAME}'"
                }'
        fi
        SCRIPT="/tmp/TZ_JSON"
        echo ${TZ_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-zones/${TZNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                TZINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${TZNAME} created succesfully"
                #echo ${TZINFO}
        else
                echo "  error creating transport zone : ${TZNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

check_ip_pool() {
        #$1 transport zone name string
        #returns json
        IPPOOLNAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                IPPOOLINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                IPPOOLCOUNT=$(echo ${IPPOOLINFO} | jq .result_count)                
                if [[ ${IPPOOLCOUNT} -gt 0 ]]
                then
                        echo $IPPOOLINFO |jq '.results[] | select (.display_name =="'$IPPOOLNAME'")'
                        IPPOOLID=$(echo $IPPOOLINFO |jq -r '.results[] | select (.display_name =="'$IPPOOLNAME'") | .id')
                        echo $IPPOOLID
                        check_ip_pool_subnet ${IPPOOLID}
                fi
        else
                echo "  error getting IP Pools"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

get_ip_pool_id() {
        #$1 transport zone name string
        #returns json
        IPPOOLNAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                IPPOOLINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                IPPOOLCOUNT=$(echo ${IPPOOLINFO} | jq .result_count)                
                if [[ ${IPPOOLCOUNT} -gt 0 ]]
                then
                        IPPOOLID=$(echo $IPPOOLINFO |jq -r '.results[] | select (.display_name =="'$IPPOOLNAME'") | .unique_id')
                        echo $IPPOOLID
                fi
        else
                echo "  error getting IP Pools"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

get_ip_pool_path() {
        #$1 transport zone name string
        #returns json
        IPPOOLNAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                IPPOOLINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                IPPOOLCOUNT=$(echo ${IPPOOLINFO} | jq .result_count)                
                if [[ ${IPPOOLCOUNT} -gt 0 ]]
                then
                        IPPOOLID=$(echo $IPPOOLINFO |jq -r '.results[] | select (.display_name =="'$IPPOOLNAME'") | .path')
                        echo $IPPOOLID
                fi
        else
                echo "  error getting IP Pools"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

get_ip_pool_all() {
        #$1 transport zone name string
        #returns json
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                IPPOOLINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                IPPOOLCOUNT=$(echo ${IPPOOLINFO} | jq .result_count)                
                if [[ ${IPPOOLCOUNT} -gt 0 ]]
                then
                        echo "${IPPOOLINFO}" > /tmp/ippoolall-json
                        echo $IPPOOLINFO |jq .
                fi
        else
                echo "  error getting IP Pools"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

check_ip_pool_subnet() {
        #$1 transport zone name string
        #returns json
        IPPOOLID=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools/${IPPOOLID}/ip-subnets)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                SUBNETINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $SUBNETINFO |jq .
        else
                echo "  error getting IP Pool subnets"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

create_ip_pool() {
        # $1 ip pool name string
        # $2 SUBNETNAME
        # $3 SUBNETSTART
        # $4 SUBNETEND
        # $5 SUBNETCIDR
        # $6 SUBNETGW

        #returns json
        IPPOOLNAME=$1
        IPPOOL_JSON='{"display_name": "'${IPPOOLNAME}'"}'

        SCRIPT="/tmp/IPPOOL_JSON"
        echo ${IPPOOL_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/ip-pools/${IPPOOLNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                IPPOOLINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${IPPOOLINFO} created succesfully"
                #echo ${IPPOOLINFO} |jq .
                IPPOOLID=$(echo ${IPPOOLINFO} |jq -r .id)
                create_ip_pool_subnet $IPPOOLID $2 $3 $4 $5 $6
        else
                echo "  error creating IP Pool : ${IPPOOLNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi

}

create_ip_pool_subnet() {
        # $1 IP POOL ID
        # $2 SUBNETNAME
        # $3 SUBNETSTART
        # $4 SUBNETEND
        # $5 SUBNETCIDR
        # $6 SUBNETGW

        #returns json

        IPPOOLID=$1
        SUBNETNAME=$2
        SUBNETSTART=$3
        SUBNETEND=$4
        SUBNETCIDR=$5
        SUBNETGW=$6

        SUBNET_JSON='{
        "display_name": "'${SUBNETNAME}'",
        "resource_type": "IpAddressPoolStaticSubnet",
        "allocation_ranges": [
        {
                "start":"'${SUBNETSTART}'",
                "end":"'${SUBNETEND}'"
        }
        ],
        "gateway_ip": "'${SUBNETGW}'",
        "cidr":"'${SUBNETCIDR}'"
        }'

        SCRIPT="/tmp/SUBNET_JSON"
        echo ${SUBNET_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PATCH -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/ip-pools/${IPPOOLID}/ip-subnets/${SUBNETNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                SUBNETINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${SUBNETNAME} created succesfully"
                #echo ${SUBNETINFO} |jq . 
        else
                echo "  error creating ip pool subnet : ${SUBNETNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi

}

check_ip_pool_subnet() {
        #$1 transport zone name string
        #returns json
        IPPOOLID=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/ip-pools/${IPPOOLID}/ip-subnets)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                SUBNETINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $SUBNETINFO |jq .
        else
                echo "  error getting IP Pool subnets"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

create_transport_node_profile() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        TNPROFILENAME=$1
        VDSUUID=$2
        HOSTTZID=$3
        OVERLAYTZID=$4
        IPPOOLID=$5
        HOSTPROFILEID=$6

        TNPROFILE_JSON='{
        "host_switch_spec": {
        "host_switches": [
        {
                "host_switch_name": "nsxDefaultHostSwitch",
                "host_switch_id": "'${VDSUUID}'",
                "host_switch_type": "VDS",
                "host_switch_mode": "STANDARD",
                "host_switch_profile_ids": [
                {
                "key": "UplinkHostSwitchProfile",
                "value": "/infra/host-switch-profiles/'${HOSTPROFILEID}'"
                }
                ],
                "uplinks": [
                {
                "vds_uplink_name": "dvUplink1",
                "uplink_name": "uplink-1"
                },
                {
                "vds_uplink_name": "dvUplink2",
                "uplink_name": "uplink-2"
                }
                ],
                "is_migrate_pnics": false,
                "ip_assignment_spec": {
                "ip_pool_id": "'${IPPOOLID}'",
                "resource_type": "StaticIpPoolSpec"
                },
                "transport_zone_endpoints": [
                        {
                        "transport_zone_id": "/infra/sites/default/enforcement-points/default/transport-zones/'${HOSTTZID}'"
                        },
                        {
                        "transport_zone_id": "/infra/sites/default/enforcement-points/default/transport-zones/'${OVERLAYTZID}'"
                        }
                ],
                "not_ready": false
        }
        ],
        "resource_type": "StandardHostSwitchSpec"
        },
        "resource_type": "PolicyHostTransportNodeProfile",
        "id": "'${TNPROFILENAME}'",
        "display_name": "'${TNPROFILENAME}'"
        }'

        SCRIPT="/tmp/TNPROFILE_JSON"
        echo ${TNPROFILE_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/host-transport-node-profiles/${TNPROFILENAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                PROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${PROFILENAME} created succesfully"
                #echo ${PROFILESINFO}
        else
                echo "  error creating transport node profile : ${TNPROFILENAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_host_transport_node_profile_id() {
        #$1 transport zone name string
        #returns json and profile id
        HTNPROFILENAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-transport-node-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                HTNPROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                HTNPROFILESCOUNT=$(echo $HTNPROFILESINFO | jq .result_count)
                echo $HTNPROFILESINFO > /tmp/htnp-json 
                if [[ ${HTNPROFILESCOUNT} -gt 0 ]]
                then
                        EXISTINGTNPROFILES=$(echo $HTNPROFILESINFO| jq -r .results[0].display_name)
                        if [[ "${EXISTINGTNPROFILES}" == "${HTNPROFILENAME}" ]]
                        then
                                echo "  host transport node profile set correctly : ${EXISTINGTNPROFILES}"
                                HTNPROFILEID=$(echo $HTNPROFILESINFO| jq -r .results[0].id)
                                echo "  host transport node profile ID : ${HTNPROFILEID}"
                        else
                                echo "  ${EXISTINGTNPROFILES} does not match ${TNPROFILENAME}"
                                echo "  stopping here"
                                exit
                        fi
                else
                        echo "  adding transport node profile"
                        create_transport_node_profile "${HTNPROFILENAME}" "${VDSUUID}" "${HOSTTZID}" "${OVERLAYTZID}" "${IPPOOLID}" "${HOSTPROFILEID}"
                fi
        else
                echo "  error getting transport node profile"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_compute_collection_external_id() {
        #$1 transport zone name string
        #returns json
        CLUSTERNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-collections)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                CCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo ${CCINFO} > /tmp/ccinfo_id_json
                CCCOUNT=$(echo ${CCINFO} | jq .result_count)
                if [[ ${CCCOUNT} -gt 0 ]]
                then
                        echo $CCINFO| jq -r '.results[] | select (.display_name =="'$CLUSTERNAME'") | .external_id'
                fi
        else
                echo "  error getting compute-collections"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_compute_collection_origin_id() {
        #$1 transport zone name string
        #returns json
        CLUSTERNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-collections)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                CCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo ${CCINFO} > /tmp/ccinfo_eid_json
                CCCOUNT=$(echo ${CCINFO} | jq .result_count)
                if [[ ${CCCOUNT} -gt 0 ]]
                then
                        echo $CCINFO| jq -r '.results[] | select (.display_name =="'$CLUSTERNAME'") | .origin_id'
                fi
        else
                echo "  error getting compute-collections"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

check_transport_node_collections() {
        #returns json
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-node-collections)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                TNCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                TNCCOUNT=$(echo ${TNCINFO} | jq .result_count)     
                echo $TNCINFO > /tmp/tnc-json 
                if [[ ${TNCCOUNT} -gt 0 ]]
                then
                        echo $TNCINFO
                else
                        echo ""
                fi
        else
                echo "  error getting transport_node_collections"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

get_transport_node_collections_state() {
        # $1 = transport node collection id
        #returns json
        TNCID=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-node-collections/${TNCID}/state)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                TNCSTATEINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $TNCSTATEINFO |jq -r .state
        else
                echo "  error getting transport_node_collections_state for ${TNCID}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit 1
        fi
}

get_host-transport-nodes() {
        #returns json
 
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/host-transport-nodes)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                CCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                CCCOUNT=$(echo ${CCINFO} | jq .result_count)
                echo $CCINFO > /tmp/htn-json 
                if [[ ${CCCOUNT} -gt 0 ]]
                then
                        echo $CCINFO |jq -r '.results[] | [.display_name, .id] |@tsv'
                else
                        echo ""
                fi
        else
                echo "  error getting host-transport-nodes"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_host-transport-nodes-state() {
        #returns json
 
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/host-transport-nodes/state)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                CCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                CCCOUNT=$(echo ${CCINFO} | jq .result_count)
                echo $CCINFO > /tmp/state-json 
                if [[ ${CCCOUNT} -gt 0 ]]
                then
                        echo $CCINFO | jq -r '.results[] | [.transport_node_id, .node_deployment_state.state] |@tsv'
                fi
        else
                echo "  error getting host-transport-nodes"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_transport_node_collections() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        CLUSTERCCID=$1
        HTNPROFILENAME=$2
        
        TNC_JSON='{
        "resource_type": "HostTransportNodeCollection",
        "compute_collection_id": "'${CLUSTERCCID}'",
        "transport_node_profile_id": "/infra/host-transport-node-profiles/'${HTNPROFILENAME}'"
        }'

        SCRIPT="/tmp/TNC_JSON"
        echo ${TNC_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/transport-node-collections/${HTNPROFILENAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 200 ]
        then
                TNCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${TNCID} created succesfully"
                echo ${TNCINFO} > /tmp/tnc-creation-response-json
        else
                echo "  error creating transport node collection : ${TNCID}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

loop_wait_host_state(){
        echo "  Checking hosts state"
        echo
        HOSTSTATE=$(get_host-transport-nodes-state)
        echo "$HOSTSTATE"
        INPROGRESS=$(echo "$HOSTSTATE" | grep -c "in_progress")
        while [[ $INPROGRESS -gt 0 ]]
        do
                echo "$HOSTSTATE"
                echo 
                sleep 10
                HOSTSTATE=$(get_host-transport-nodes-state)
                INPROGRESS=$(echo "$HOSTSTATE" | grep -c "in_progress")
        done

}

get_segment(){
        #$1 segments name to look for
        #returns json
        SEGMENTNAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/segments)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                SEGMENTSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                SEGMENTSCOUNT=$(echo ${SEGMENTSINFO} | jq .result_count)
                echo $SEGMENTSINFO > /tmp/segment-json 
                if [[ ${SEGMENTSCOUNT} -gt 0 ]]
                then
                        if [ "$SEGMENTNAME" == "" ]
                        then
                                echo $SEGMENTSINFO |jq -r '.results[] | [.display_name, .id] |@tsv'
                        else
                                echo $SEGMENTSINFO |jq -r '.results[] | select (.display_name =="'$SEGMENTNAME'") | .id'
                        fi
                else
                        echo ""
                fi
        else
                echo "  error getting segments"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_edge_segment() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        SEGMENTNAME=$1
        TZID=$2
        TEAMINGPOLICY=$3

        SEGMENT_JSON='{
        "display_name": "'${SEGMENTNAME}'",
        "vlan_ids": ["0-4094"],
        "transport_zone_path": "/infra/sites/default/enforcement-points/default/transport-zones/'${TZID}'",
        "advanced_config": {
        "uplink_teaming_policy_name": "'${TEAMINGPOLICY}'"
        }
        }'

        SCRIPT="/tmp/SEGMENT_JSON"
        echo ${SEGMENT_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/segments/${SEGMENTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                SEGMENTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${SEGMENTNAME} created succesfully"
                # echo ${SEGMENTINFO} |jq .
        else
                echo "  error creating segment : ${TNCID}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_transport_node(){
        #$1 segments name to look for
        #returns json
        EDGENODENAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/transport-nodes)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                TNINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                TNCOUNT=$(echo ${TNINFO} | jq .result_count)
                echo $TNINFO > /tmp/edgenodes-json 
                if [[ ${TNCOUNT} -gt 0 ]]
                then
                        if [ "$EDGENODENAME" == "" ]
                        then
                                echo "${TNINFO}" |jq -r '.results[] | [.display_name, .id] |@tsv'
                        else
                                echo "${TNINFO}" |jq -r '.results[] | select (.display_name =="'$EDGENODENAME'") | .id'
                        fi
                else
                        echo ""
                fi
        else
                echo "  error getting transport-nodes"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_edge_node() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        EDGENAME=$1
        UPLINKPROFILEID=$2
        IPPOOLID=$3
        OVLYTZID=$4
        VLANTZID=$5
        CLUSTERCCID=$6
        COMPUTE_ID=$7
        STORAGE_ID=$8
        MANAGEMENT_NETWORK_ID=$9
        EDGE_IP=${10}
        FQDN=${11}

        EDGE_JSON='{
        "display_name": "'${EDGENAME}'",
        "host_switch_spec": {
                "host_switches": [
                {
                        "host_switch_name": "nsxHostSwitch",
                        "host_switch_type": "NVDS",
                        "host_switch_mode": "STANDARD",
                        "host_switch_profile_ids": [
                        {
                                "key": "UplinkHostSwitchProfile",
                                "value": "'${UPLINKPROFILEID}'"
                        }
                        ],
                        "pnics": [
                        {
                                "device_name": "fp-eth0",
                                "uplink_name": "uplink-1"
                        },
                        {
                                "device_name": "fp-eth1",
                                "uplink_name": "uplink-2"
                        }
                        ],
                        "is_migrate_pnics": false,
                        "ip_assignment_spec": {
                        "ip_pool_id": "'${IPPOOLID}'",
                        "resource_type": "StaticIpPoolSpec"
                        },
                        "cpu_config": [],
                        "transport_zone_endpoints": [
                        {
                                "transport_zone_id": "'${OVLYTZID}'",
                                "transport_zone_profile_ids": [
                                {
                                        "resource_type": "BfdHealthMonitoringProfile",
                                        "profile_id": "52035bb3-ab02-4a08-9884-18631312e50a"
                                }
                                ]
                        },
                        {
                                "transport_zone_id": "'${VLANTZID}'",
                                "transport_zone_profile_ids": [
                                {
                                        "resource_type": "BfdHealthMonitoringProfile",
                                        "profile_id": "52035bb3-ab02-4a08-9884-18631312e50a"
                                }
                                ]
                        }
                        ],
                        "not_ready": false
                }
                ],
                "resource_type": "StandardHostSwitchSpec"
        },
        "maintenance_mode": "DISABLED",
        "node_deployment_info": {
                "deployment_type": "VIRTUAL_MACHINE",
                "deployment_config": {
                "vm_deployment_config": {
                        "vc_id": "'${CLUSTERCCID}'",
                        "compute_id": "'${COMPUTE_ID}'",
                        "storage_id": "'${STORAGE_ID}'",
                        "management_network_id": "'${MANAGEMENT_NETWORK_ID}'",
                        "management_port_subnets": [
                        {
                                "ip_addresses": [
                                "'${EDGE_IP}'"
                                ],
                                "prefix_length": 24
                        }
                        ],
                        "default_gateway_addresses": [
                        "'${CPODROUTERIP}'"
                        ],
                        "data_network_ids": [
                        "/infra/segments/edge-uplink-trunk-1",
                        "/infra/segments/edge-uplink-trunk-2"
                        ],
                        "reservation_info": {
                        "memory_reservation": {
                                "reservation_percentage": 0
                        },
                        "cpu_reservation": {
                                "reservation_in_shares": "NORMAL_PRIORITY",
                                "reservation_in_mhz": 0
                        }
                        },
                        "placement_type": "VsphereDeploymentConfig"
                },
                "form_factor": "LARGE",
                "node_user_settings": {
                        "cli_username": "admin",
                                        "root_password":"'${PASSWORD}'",
                                        "cli_password":"'${PASSWORD}'"
                }
                },
                "node_settings": {
                "hostname": "'${FQDN}'",
                "search_domains": [
                        "'${DOMAIN}'"
                ],
                "ntp_servers": [
                        "'${CPODROUTERIP}'"
                ],
                "dns_servers": [
                        "'${CPODROUTERIP}'"
                ],
                "enable_ssh": true,
                "allow_ssh_root_login": true
                },
                "resource_type": "EdgeNode",
                "ip_addresses": [
                "'${EDGE_IP}'"
                ]
        }
        }'

        SCRIPT="/tmp/EDGE_JSON"
        echo ${EDGE_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/transport-nodes)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 201 ]
        then
                EDGEINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${EDGENAME} created succesfully"
                echo "${EDGEINFO}" > /tmp/${EDGENAME}-json
        else
                echo "  error creating edge node  : ${EDGENAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

loop_get_edge_nodes_state(){

        #returns json

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/transport-nodes)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                echo
                echo "Checking Edge Nodes deployment status"
                echo

                NODESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                EDGENODESIDS=$(echo "${NODESINFO}" | jq -r '.results[] | select (.node_deployment_info.resource_type =="EdgeNode") | .id')
                EDGENODESCOUNT=$(echo "${EDGENODESIDS}" | wc -l)
                echo $NODESINFO > /tmp/edgenodes-list-json 
                if [[ ${EDGENODESCOUNT} -gt 0 ]]
                then
                        EDGESTATUSREADYCOUNT=0
                        while [ ${EDGESTATUSREADYCOUNT} -lt  ${EDGENODESCOUNT} ]
                        do
                                EDGESTATUSREADYCOUNT=0
                                for EDGENODEID in ${EDGENODESIDS}; do
                                        EDGESTATEINFO=$(get_edge_node_state $EDGENODEID)
                                        EDGENODESTATE=$( echo "${EDGESTATEINFO}" |jq -r .state)
                                        EDGENODEDEPLOYMENTSTATE=$(echo "${EDGESTATEINFO}" |jq -r .node_deployment_state.state )
                                        echo "  ${EDGENODEID} - ${EDGENODESTATE} - ${EDGENODEDEPLOYMENTSTATE}" 
                                        if [ "${EDGENODESTATE}" == "success" ];
                                        then
                                                EDGESTATUSREADYCOUNT=$((EDGESTATUSREADYCOUNT+1))
                                        fi
                                done
                                echo "  EDGE READY COUNT : ${EDGESTATUSREADYCOUNT} / ${EDGENODESCOUNT} "
                                [ ${EDGESTATUSREADYCOUNT} -lt  ${EDGENODESCOUNT} ] && sleep 30
                        done
                fi
        else
                echo "  error getting transport-nodes info"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_edge_node_state(){
        #$1 edge node id to look for
        #returns json

        EDGENODEID=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/transport-nodes/${EDGENODEID}/state)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                EDGENODEINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${EDGENODEINFO}"
        else
                echo "  error getting edge nodes state"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_edge_clusters(){
        #$1 segments name to look for
        #returns json
  
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/edge-clusters)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                EDGECLUSTERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                EDGECLUSTERSCOUNT=$(echo ${EDGECLUSTERSINFO} | jq .result_count)
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json 
                if [[ ${EDGECLUSTERSCOUNT} -gt 0 ]]
                then
                        echo "${EDGECLUSTERSINFO}" |jq -r '.results[]'
                else
                        echo ""
                fi
        else
                echo "  error getting edge-clusters"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_edge_cluster() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        EDGEID1=$1
        EDGEID2=$2

        EDGECLUSTER_JSON='{
        "member_node_type": "EDGE_NODE",
        "resource_type": "EdgeCluster",
        "display_name": "edge-cluster",
        "deployment_type": "VIRTUAL_MACHINE",
        "members":  [
        {
                "transport_node_id": "'${EDGEID1}'"
        },
        {
                "transport_node_id": "'${EDGEID2}'"
        }
        ],
        "cluster_profile_bindings": [
                {
                "resource_type": "EdgeHighAvailabilityProfile",
                "profile_id": "91bcaa06-47a1-11e4-8316-17ffc770799b"
                }
        ]
        }'

        SCRIPT="/tmp/EDGECLUSTER_JSON"
        echo ${EDGECLUSTER_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/edge-clusters)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 201 ]
        then
                EDGECLUSTERINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  Edge-cluster created succesfully"
                echo "${EDGECLUSTERINFO}" > /tmp/edge-cluster-created-json
        else
                echo "  error creating edge cluster  : ${EDGENAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_edge_clusters_id(){
        #$1 segments name to look for
        #returns json
        EDGECLUSTERNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/edge-clusters)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                EDGECLUSTERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                EDGECLUSTERSCOUNT=$(echo ${EDGECLUSTERSINFO} | jq .result_count)
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json 
                if [[ ${EDGECLUSTERSCOUNT} -gt 0 ]]
                then
                        echo "${EDGECLUSTERSINFO}" |jq -r '.results[] | select (.display_name == "'${EDGECLUSTERNAME}'") | .id'
                else
                        echo ""
                fi
        else
                echo "  error getting edge-clusters"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_t0_segment() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        SEGMENTNAME=$1
        TZID=$2
        TEAMINGPOLICY=$3
        UPLINKSVLANID=$4

        SEGMENT_JSON='{
        "display_name": "'${SEGMENTNAME}'",
        "vlan_ids": ['${UPLINKSVLANID}'],
        "transport_zone_path": "/infra/sites/default/enforcement-points/default/transport-zones/'${TZID}'",
        "advanced_config": {
        "uplink_teaming_policy_name": "'${TEAMINGPOLICY}'"
        }
        }'

        SCRIPT="/tmp/SEGMENT_JSON"
        echo ${SEGMENT_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/segments/${SEGMENTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                SEGMENTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${SEGMENTNAME} created succesfully"
                echo ${SEGMENTINFO} > /tmp/t0-segment-create.json
        else
                echo "  error creating t0 segment : ${SEGMENTNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi

}

get_tier-0s(){
        SEGMENTNAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0COUNT=$(echo ${T0INFO} | jq .result_count)
                echo $T0INFO > /tmp/t0-json 
                if [[ ${T0COUNT} -gt 0 ]]
                then
                        echo "${T0INFO}" |jq -r '.results[]'
                        if [ "$SEGMENTNAME" == "" ]
                        then
                                echo $T0INFO |jq -r '.results[] | [.display_name, .id] |@tsv'
                        else
                                echo $T0INFO |jq -r '.results[] | select (.display_name =="'$SEGMENTNAME'") | .id'
                        fi
                else
                        echo ""
                fi
        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_t0_gw() {
        #
        T0NAME=$1
        
        T0GW_JSON='{ "ha_mode":"ACTIVE_ACTIVE" }'
        SCRIPT="/tmp/T0GW_JSON"
        echo ${T0GW_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0GWINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${T0NAME} created succesfully"
                echo ${T0GWINFO} > /tmp/t0-gw-create.json

        else
                echo "  error creating T0 GW : ${T0NAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_locale_services(){
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/Tier-0/locale-services)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0COUNT=$(echo ${T0INFO} | jq .result_count)
                echo $T0INFO > /tmp/t0-local_services-json 
                if [[ ${T0COUNT} -gt 0 ]]
                then
                        echo "${T0INFO}" |jq -r .
                else
                        echo ""
                fi
        else
                echo "  error getting Tier-0s locale_services"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_t0_locale_service() {
        #
        T0NAME=$1
        EDGECLUSTERID=$2
        EDGECLUSTERPATH="/infra/sites/default/enforcement-points/default/edge-clusters/${EDGECLUSTERID}"

        T0_LS_JSON='{
        "edge_cluster_path": "'${EDGECLUSTERPATH}'"
        }'
        SCRIPT="/tmp/T0_LS_JSON"
        echo ${T0_LS_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0GWINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${T0NAME} created succesfully"
                echo ${T0GWINFO} > /tmp/t0-ls-create.json

        else
                echo "  error creating T0 locale_service : default"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_interfaces(){
        #https://${NSXFQDN}/policy/api/v1/infra/tier-0s/Tier-0/locale-services/default/interfaces
        T0NAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/interfaces)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0INTCOUNT=$(echo ${T0INTINFO} | jq .result_count)
                echo $T0INTINFO > /tmp/t0-interfaces-json 
                if [[ ${T0INTCOUNT} -gt 0 ]]
                then
                        echo "${T0INTINFO}" |jq -r .
                else
                        echo ""
                fi
        else
                echo "  error getting Tier-0s interfaces"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_edge_node_cluster_member_index(){
        #$1 segments name to look for
        #returns json
        EDGECLUSTERNAME=$1
        EDGENODENAME=$2
  
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/edge-clusters)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                EDGECLUSTERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                EDGECLUSTERSCOUNT=$(echo ${EDGECLUSTERSINFO} | jq .result_count)
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json 
                if [[ ${EDGECLUSTERSCOUNT} -gt 0 ]]
                then
                        CLUSTER=$(echo "${EDGECLUSTERSINFO}" |jq '.results[] | select (.display_name =="'${EDGECLUSTERNAME}'")' )
                        echo $CLUSTER |jq '.members[] | select (.display_name == "'${EDGENODENAME}'") | .member_index'
                else
                        echo ""
                fi
        else
                echo "  error getting edge-clusters"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_t0_interface() {
        #
        T0NAME=$1
        EDGECLUSTERID=$2
        INTIP=$3
        SEGMENT=$4
        EDGENODEIDX=$5
        INTNAME=$6

        EDGECLUSTERPATH="/infra/sites/default/enforcement-points/default/edge-clusters/${EDGECLUSTERID}/edge-nodes/${EDGENODEIDX}"

        T0_INT_JSON='{
        "segment_path": "/infra/segments/'${SEGMENT}'",
        "subnets": [
        {
        "ip_addresses": [ "'${INTIP}'" ],
        "prefix_len": 24
        }
        ],
        "edge_path": "'${EDGECLUSTERPATH}'",
        "type": "EXTERNAL"
        }'
        SCRIPT="/tmp/T0_INT_JSON"
        echo ${T0_INT_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/interfaces/${INTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${INTNAME} created succesfully"
                echo ${T0INTINFO} > /tmp/t0-int-create.json

        else
                echo "  error creating T0 interface : ${INTNAME} "
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_bgp(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-json 
                echo "${BGPINFO}" 
        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

# /policy/api/v1/infra/tier-0s/Tier-0/locale-services/default/bgp

configure_tier-0s_bgp(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        ASNNUMBER=$2

        T0_BGP_JSON='{
        "local_as_num": "'${ASNNUMBER}'",
        "enabled": true
        }'
        SCRIPT="/tmp/T0_BGP_JSON"
        echo ${T0_BGP_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-configured-json 
                echo "  BGP Enabled succesfully with ASN : ${ASNNUMBER}" 
        else
                echo "  error configuring Tier-0s BGP"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}
# /policy/api/v1/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors

get_tier-0s_bgp_neighbors(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp/neighbors)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-neighbors-json 
                echo "${BGPINFO}" | jq .results[]
        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

configure_tier-0s_bgp_neighbor(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        NBIP=$2
        NBASN=$3
        NBNAME=$4

        T0_NB_JSON='{
        "neighbor_address": "'${NBIP}'",
        "remote_as_num": "'${NBASN}'"
        }'
        SCRIPT="/tmp/T0_NB_JSON"
        echo ${T0_NB_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp/neighbors/${NBNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json 
                echo "  BGP Neighbor ${NBNAME} added successully" 
        else
                echo "  error configuring Tier-0s BGP Neighbor ${$NBNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_logical_router_id(){
        
        T0NAME=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/logical-routers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $LRINFO > /tmp/logical-routers-json 
                ROUTER=$(echo "${LRINFO}" | jq -r '.results[] | select (.display_name == "'${T0NAME}'")')
                if [ "${ROUTER}" != "" ]
                then
                        echo "${LRINFO}" | jq -r '.results[] | select (.display_name == "'${T0NAME}'") | .id'
                else
                        echo ""
                fi


        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

# /api/v1/logical-routers/<logical-router-id>/routing/redistribution

get_logical_router_redistribution_bgp(){
        
        LRID=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $LRINFO > /tmp/logical-routers-redist-json 
                ROUTER=$(echo "${LRINFO}" | jq -r '.bgp_enabled')
        else
                echo "  error getting Tier-0s routing redistribution"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_logical_router_redistribution_bgp_revision(){
        
        LRID=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $LRINFO > /tmp/logical-routers-redist-json 
                echo "${LRINFO}" | jq -r '._revision'
        else
                echo "  error getting Tier-0s routing redistribution"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

configure_tier-0s_bgp_redistribution(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        LRID=$1
        REVISION=$(get_logical_router_redistribution_bgp_revision "${LRID}")
        T0_LR_JSON='{
        "resource_type": "RedistributionConfig",
        "display_name": "BGP route redistribution",
        "bgp_enabled": true,
        "_revision": '${REVISION}'
        }'
        SCRIPT="/tmp/T0_LR_JSON"
        echo ${T0_LR_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution )
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-redist-configured-json 
                echo "  BGP route redistribution set successully" 
        else
                echo "  error configuring Tier-0s BGP redistribution"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_logical_router_redistribution_bgp_revision_rules(){
        
        LRID=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution/rules)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $LRINFO > /tmp/logical-routers-redist-rules-json 
                ROUTER=$(echo "${LRINFO}" | jq -r '.rules[]')
        else
                echo "  error getting Tier-0s routing redistribution"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_logical_router_redistribution_bgp_rules_reivision(){
        
        LRID=$1
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution/rules)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                LRINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $LRINFO > /tmp/logical-routers-redist-rules-json 
                ROUTER=$(echo "${LRINFO}" | jq -r '._revision')
        else
                echo "  error getting Tier-0s routing redistribution"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

configure_tier-0s_bgp_redistribution_rules(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        LRID=$1
        REVISION=$(get_logical_router_redistribution_bgp_rules_reivision "${LRID}")
        T0_RDST_RULES_JSON='{
        "_revision": '${REVISION}',
        "rules": [{
        "sources" : [ "T1_CONNECTED", "T1_STATIC", "T1_LB_VIP", "T1_NAT" ],
        "destinations" : [ "BGP" ],
        "destination" : "BGP",
        "address_family" : "IPV4_AND_IPV6",
        "display_name" : "default"
        }
        ]
        }'
        SCRIPT="/tmp/T0_RDST_RULES_JSON"
        echo ${T0_RDST_RULES_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution/rules )
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-redist-rules-configured-json 
                echo "  BGP route redistribution rules set successully" 
        else
                echo "  error configuring Tier-0s BGP redistribution rules"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier0_route_redistribution() {
 #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                ROUTEINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                ROUTEREDIST=$(echo ${ROUTEINFO} | jq .route_redistribution_config)
        else
                echo "  error configuring Tier-0s BGP Neighbor ${$NBNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

patch_tier0_route_redistribution() {
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1

        T0_RULES_JSON='{
        "route_redistribution_config" : {
        "bgp_enabled" : true,
        "ospf_enabled" : false,
        "redistribution_rules" : [ {
        "name" : "default",
        "route_redistribution_types" : [ "TIER1_LB_VIP", "TIER1_NAT", "TIER1_CONNECTED", "TIER1_STATIC" ],
        "destinations" : [ "BGP" ]
        } ]
        }
        }'
        SCRIPT="/tmp/T0_RULES_JSON"
        echo ${T0_RULES_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PATCH -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json 
                echo "  BGP Neighbor ${NBNAME} added successully" 
        else
                echo "  error configuring Tier-0s BGP Neighbor ${NBNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
        
}

###################
CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
VMNAME="${VAPP}-${HOSTNAME}"
CPODROUTERIP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ${CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

if [ ${VLAN} -gt 40 ]; then
	VMOTIONVLANID=${VLAN}1
	VSANVLANID=${VLAN}2
	TEPVLANID=${VLAN}3
        UPLINKSVLANID=${VLAN}4
else
	VMOTIONVLANID=${VLAN}01
	VSANVLANID=${VLAN}02
	TEPVLANID=${VLAN}03
        UPLINKSVLANID=${VLAN}04
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# ===== Start of code =====

NSXFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}
echo ${NSXFQDN}

# ===== checking nsx version =====
echo
echo "Checking nsx version"
echo

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/node/version)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        VERSIONINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        PRODUCTVERSION=$(echo $VERSIONINFO |jq -r .product_version)
        echo "  Product: ${PRODUCTVERSION}"
        #Check if 3.2 or 4.1 or better. if not stop script.
        MAJORVERSION=$(echo ${PRODUCTVERSION} | head -c1)
        MINORVERSION=$(echo ${PRODUCTVERSION} | head -c3)
       	case $MAJORVERSION in
		3)
		        LOWESTVERSION=$(printf "%s\n" "3.2" ${MINORVERSION} | sort -V | head -n1)
                        echo "  lowestversion: $LOWESTVERSION"
                        if [[ "${LOWESTVERSION}" == "3.2" ]]
                        then
                                echo "  Version is at lease 3.2"
                        else
                                echo "  Version is below 3.2. Script uses newer API (>3.2 or >4.1). stopping here."
                                exit
                        fi
			;;
		4)
		        LOWESTVERSION=$( printf "%s\n" "4.1" ${MINORVERSION} | sort -V | head -n1)
                        echo "lowestversion: $LOWESTVERSION"
                        if [[ "${LOWESTVERSION}" == "4.1" ]]
                        then
                                echo "Version is at lease 4.1"
                        else
                                echo "Version is below 4.1. Script uses newer API (>3.2 or >4.1). stopping here."
                                exit
                        fi			
			;;
		*)
		        echo "This script is not ready yet for nsx-t version $MAJORVERSION"
                        exit
		        ;;
	esac

else
        echo "  error getting version"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


#======== Accept Eula ========
echo
echo "Accepting EULA and settting CEIP"
echo

#nsx_accept_eula
#nsx_ceip_agreement
#nsx_ceip_telemetry


#======== License NSX-T ========

#check License
echo
echo "Checking NSX Licenses"
echo
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/licenses)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        LICENSESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        LICENSESCOUNT=$(echo $LICENSESINFO | jq .result_count)
        if [[ ${LICENSESCOUNT} -gt 0 ]]
        then
                EXISTINGLIC=$(echo ${LICENSESINFO} |jq '.results[] | select (.description =="NSX Data Center Enterprise Plus")')
                if [[ "${EXISTINGLIC}" == "" ]]
                then
                        echo "  No NSX datacenter License present."
                        echo "  adding NSX license"
                        add_nsx_license
                else
                        echo "  NSX Datacenter license present. proceeding with configuration"
                fi
        else
                echo "  No License assigned."
                echo "  add NSX License"
                add_nsx_license                
        fi
else
        echo "  error getting licenses"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi


#======== get venter thumbprint ========

VCENTERTP=$(echo | openssl s_client -connect vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}:443 2>/dev/null | openssl x509 -noout -fingerprint -sha256 | cut -d "=" -f2)

# ===== add computer manager =====
# Check existing manager
echo
echo "Processing computer manager"
echo

MGRNAME="vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
MGRTEST=$(get_compute_manager "${MGRNAME}")

if [ "${MGRTEST}" != "" ]
then
        echo "  ${MGRTEST}"
        MGRID=$(get_compute_manager_id "${MGRNAME}")
        #get_compute_manager_status "${MGRID}"
        loop_wait_compute_manager_status "${MGRID}"
else
        echo "  Adding Compute Manager"
        add_computer_manager "${MGRNAME}"
        sleep 30
        MGRID=$(get_compute_manager_id "${MGRNAME}")
        loop_wait_compute_manager_status "${MGRID}"
fi


# ===== Create Uplink profiles =====
# Check existing uplink profiles
# 1 for edge
# 1 for hosts
echo
echo "processing uplink profiles"
echo

EDGE=$(check_uplink_profile "edge-profile")
if [ "${EDGE}" == "" ]
then
        echo "  create edge-profile"
        create_uplink_profile "edge-profile" $TEPVLANID
else 
        echo "  edge-profile exists"
        #echo $EDGE
fi

HOST=$(check_uplink_profile "host-profile")
if [ "${HOST}" == "" ]
then
        echo "  create host-profile"
        create_uplink_profile "host-profile" $TEPVLANID
else 
        echo "  host-profile exists"
        #echo $HOST
fi

# ===== Create transport zones =====
# Check existing uplink profiles
# 1 for edge
# 1 for hosts
# 1 for overlay
# because we can ! and we are following the NSX best practices

echo
echo "processing transport zones"
echo

echo "  get enforcement points"
echo

RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        EPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        EPCOUNT=$(echo ${EPINFO} | jq .result_count)
        if [[ ${EPCOUNT} -gt 0 ]]
        then
                EXISTINGEP=$(echo $EPINFO| jq -r '.results[].display_name')
                #echo $EXISTINGEP
                EXISTINGEPRP=$(echo $EPINFO| jq -r '.results[].relative_path')
                #echo $EXISTINGEPRP
                
                if [[ "${EXISTINGEP}" == "default" ]]
                then
                        echo "  existing EP is default"
                else
                        echo "  ${EXISTINGEP} does not match default"
                fi
        else
                echo "TODO : what when no EP ?"
                exit
        fi
else
        echo "  error getting enforcement-points"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

EDGE=$(check_transport_zone "edge-vlan-tz")
if [ "${EDGE}" == "" ]
then
        echo "  create check_transport_zone "edge-vlan-tz""
        create_transport_zone "edge-vlan-tz" "VLAN_BACKED" "edge-profile"
else 
        echo "  edge-vlan-tz exists"
        #echo $EDGE
fi

HOST=$(check_transport_zone "host-vlan-tz")
if [ "${HOST}" == "" ]
then
        echo "  create check_transport_zone "host-vlan-tz""
        create_transport_zone "host-vlan-tz" "VLAN_BACKED" "host-profile"
else 
        echo "  host-vlan-tz exists"
        #echo $HOST
fi

OVERLAY=$(check_transport_zone "overlay-tz")
if [ "${OVERLAY}" == "" ]
then
        echo "  create check_transport_zone "overlay-tz""
        create_transport_zone "overlay-tz" "OVERLAY_STANDARD"
else 
        echo "  overlay-tz exists"
        #echo $OVERLAY
fi

# ===== create IP pools =====

#/policy/api/v1/infra/ip-pools
#Check if one present
#Check if subnets present

POOL=$(check_ip_pool "TEP-pool")
if [ "${POOL}" == "" ]
then
        echo "  create TEP IP pool"
        create_ip_pool "TEP-pool" "TEP-pool-subnet"  "10.${VLAN}.3.2" "10.${VLAN}.3.200" "10.${VLAN}.3.0/24"  "10.${VLAN}.3.1" 
else 
        echo "  TEP-pool exists"
fi

# ===== transport node profile =====
# Check existing transport node profile

echo
echo "Processing Transport Node"
echo

# get vds uuid
./extra/govc_cpod.sh  ${NAME_LOWER}  2>&1 > /dev/null
GOVCSCRIPT=/tmp/scripts/govc_${CPOD_NAME_LOWER}
source ${GOVCSCRIPT}
# VDS UUID
# govc ls -json=true network |jq -r '.elements[] | select ( .Object.Summary.ProductInfo.Name == "DVS") |  .Object.Summary.Uuid'

#VDSUUID=$(govc find / -type DistributedVirtualSwitch | xargs -n1 govc dvs.portgroup.info | grep DvsUuid | uniq | cut -d":" -f2 | awk '{$1=$1;print}')
VDSUUID=$(govc ls -json=true network |jq -r '.elements[] | select ( .Object.Summary.ProductInfo.Name == "DVS") |  .Object.Summary.Uuid')
echo "  VDS UUID : ${VDSUUID}"
if [ "${VDSUUID}" == "" ]
then
        echo "  problem getting VDS UUID"
        exit
fi
#get Host Profile ID
HOSTPROFILEID=$(get_uplink_profile_id "host-profile")
echo "  HOST Profile ID: ${HOSTPROFILEID}"

#get transport zones ids
HOSTTZID=$(get_transport_zone_id "host-vlan-tz")
echo "  HOST TZ ID: ${HOSTTZID}"
OVERLAYTZID=$(get_transport_zone_id "overlay-tz")
echo "  OVERLAY TZ ID: ${OVERLAYTZID}"

#GET IP POOL ID
IPPOOLID=$(get_ip_pool_path "TEP-pool")
echo "  IP POOL ID : ${IPPOOLID}"

echo
echo "Checking Transport Nodes Profile"
HTNPROFILENAME="cluster-transport-node-profile"

## need to add check that vcenter inventory completed in NSX Manager

get_host_transport_node_profile_id "${HTNPROFILENAME}" "${VDSUUID}" "${HOSTTZID}" "${OVERLAYTZID}" "${IPPOOLID}" "${HOSTPROFILEID}"

# ===== Configure NSX on ESX hosts =====
echo
echo Configuring NSX on ESX hosts
echo

CLUSTERCCID=$(get_compute_collection_external_id "Cluster")
echo "  Cluster CCID : ${CLUSTERCCID}" 

# check current state
echo "  get_host-transport-nodes"
echo
get_host-transport-nodes
TNC=$(check_transport_node_collections)
if [ "${TNC}" != ""  ]
then
        TNCID=$(echo ${TNC} |jq -r '.results[] | select (.compute_collection_id == "'${CLUSTERCCID}'") | .id ' )
        echo
        echo "  TNCID: $TNCID"
        echo "  Cluster Collection State :  $(get_transport_node_collections_state ${TNCID})"
        echo
        loop_wait_host_state
else
        echo "  Configuring NSX on hosts"
        echo
        create_transport_node_collections "${CLUSTERCCID}" "${HTNPROFILENAME}"
        sleep 30
        loop_wait_host_state
fi


# ===== create nsx segments for edge vms =====
# edge-uplink-trunk-1 - tz = host-vlan-tz - teaming policy : host-profile-uplink-1 - vlan : 0-4094
# edge-uplink-trunk-2 - tz = host-vlan-tz - teaming policy : host-profile-uplink-2 - vlan : 0-4094
echo "Processing segments"
echo
if [ "$(get_segment "edge-uplink-trunk-1")" == "" ]
then
        TZID=$(get_transport_zone_id "host-vlan-tz")
        create_edge_segment "edge-uplink-trunk-1" "$TZID" "host-profile-uplink-1"
else
        echo "  edge-uplink-trunk-1 - present"
fi
echo
if [ "$(get_segment "edge-uplink-trunk-2")" == "" ]
then
        TZID=$(get_transport_zone_id "host-vlan-tz")
        create_edge_segment "edge-uplink-trunk-2" "$TZID" "host-profile-uplink-2"
else
        echo "  edge-uplink-trunk-2 - present"
fi


# ===== create edge nodes =====
# edge-1 - fqdn : edge-1.cpod... - size : large 
# set password
# allow ssh for admin
# set computer manager: vcenter - cluster - datastore : vsandatastore
# node settings : ip : mgmt.54/24 - GW - Portgroup (vm network / vds pg : mgmt - search domain - dns - ntp )
# "configure nsx" - "new node switch" - switch name nsxHostSwitch - TZ : edge-vlan-tz + overlay-tz - uplink : edge-profile - ip assignment : ip pool - ip pool : TEP-pool - /
# teaming policy uplink mapping : type "vlan segment" : "edge-uplink-trunk-1" / 2

#get vCenter objects details

# Cluster ID
CLUSTERCCID=$(get_compute_collection_origin_id "Cluster")

# govc ls -json=true host |jq -r '.elements[].Object.Self.Value'
COMPUTE_ID=$(govc ls -json=true host |jq -r '.elements[].Object.Self.Value')
#COMPUTE_ID=$(get_compute_manager_id "${MGRNAME}")

# Datastore ID
# govc datastore.info -json=true vsanDatastore |jq -r .Datastores[].Self.Value
STORAGE_ID=$(govc datastore.info -json=true vsanDatastore |jq -r .Datastores[].Self.Value)

# Portgroup ID
# govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="vlan-0-mgmt") | .Network.Value'
# 
MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="vlan-0-mgmt") | .Network.Value')
if [ "${MANAGEMENT_NETWORK_ID}" == "" ]
then
        MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="VM Network") | .Network.Value')
fi

OVLYTZID=$(get_transport_zone_uniqueid "overlay-tz")
VLANTZID=$(get_transport_zone_uniqueid "edge-vlan-tz")

#OVLYTZID=$(get_transport_zone_path "overlay-tz")
#VLANTZID=$(get_transport_zone_path "edge-vlan-tz")

#UPLINKPROFILEID=$(get_uplink_profile_uniqueid "edge-profile")
UPLINKPROFILEID=$(get_uplink_profile_path "edge-profile")

#get_ip_pool_all
IPPOOLID=$(get_ip_pool_id "TEP-pool")

# deploy edge code here
echo "edge-1"
EDGEID=$(get_transport_node "edge-1")
if [ "${EDGEID}" == "" ]
then
        EDGE_IP="${SUBNET}.54"
        FQDN="edge-1.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
        create_edge_node "edge-1" "${UPLINKPROFILEID}" "${IPPOOLID}" "${OVLYTZID}" "${VLANTZID}" "${CLUSTERCCID}" "${COMPUTE_ID}" "${STORAGE_ID}" "${MANAGEMENT_NETWORK_ID}" "${EDGE_IP}" "${FQDN}"
else
        echo "  edge-1 is present"
fi

echo "edge-2"

EDGEID=$(get_transport_node "edge-2")
if [ "${EDGEID}" == "" ]
then
        EDGE_IP="${SUBNET}.55"
        FQDN="edge-2.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
        create_edge_node "edge-2" "${UPLINKPROFILEID}" "${IPPOOLID}" "${OVLYTZID}" "${VLANTZID}" "${CLUSTERCCID}" "${COMPUTE_ID}" "${STORAGE_ID}" "${MANAGEMENT_NETWORK_ID}" "${EDGE_IP}" "${FQDN}"
else
        echo "  edge-2 is present"
fi

# check edge node status - Not Available -> ready  in "configuration state" - "Registration Pending" - Success

loop_get_edge_nodes_state


# ===== create edge cluster =====
# create edge cluster and add nodes to it

echo
echo "Checking Edge Clusters"
echo

EDGECLUSTERS=$(get_edge_clusters)
if [ "${EDGECLUSTERS}" != "" ];
then
        echo "  Edge Clusters exist"
else
        EDGEID1=$(get_transport_node "edge-1")
        EDGEID2=$(get_transport_node "edge-2")
        create_edge_cluster $EDGEID1 $EDGEID2
fi

# ===== create nsx segments for T0 =====
# name: t0-uplink-1 - no gw - tz : edge-vlan-tz - teaming : edge-uplink-1 - vlan id : VLAN#4 (uplinks)
echo
echo "Processing T0 segment"
echo

T0SEGMENTNAME="t0-uplink-1"

if [ "$(get_segment "${T0SEGMENTNAME}")" == "" ]
then
        TZID=$(get_transport_zone_id "edge-vlan-tz")
        create_t0_segment "${T0SEGMENTNAME}" "$TZID" "edge-profile-uplink-1" "${UPLINKSVLANID}"
else
        echo "  ${T0SEGMENTNAME} - present"
fi

# ===== create T0 =====
# create TO in network - T0 gateways
# name : Tier-0 - HA mode : active-active - edge cluster : edge-cluster
# save
echo
echo "Processing T0 gateway"
echo

T0GWNAME="Tier-0"

if [ "$(get_tier-0s "${T0GWNAME}")" == "" ]
then
        create_t0_gw "${T0GWNAME}"
else
        echo "  ${T0GWNAME} - present"
fi

echo
echo "  Checking locale_services"
echo 

if [ "$(get_tier-0s_locale_services)" == "" ]
then
        EDGECLUSTERID=$(get_edge_clusters_id "edge-cluster")
        create_t0_locale_service "${T0GWNAME}" "${EDGECLUSTERID}"
else
        echo "  locale_services present"
fi

# set interfaces
# add interfce
# name : edge-1-uplink-1 - type : external - ip : 10.vlan.4.11 - segment : t0-uplink-1 - edge node : edge-1
# add interfce
# name : edge-2-uplink-2 - type : external - ip : 10.vlan.4.12 - segment : t0-uplink-1 - edge node : edge-2

echo
echo "  Checinkg interfaces"
echo

T0IP01="10.${VLAN}.4.11"
T0IP02="10.${VLAN}.4.12"

INTERFACES=$(get_tier-0s_interfaces  "${T0GWNAME}")

if [ "${INTERFACES}" == "" ]
then
        EDGECLUSTERID=$(get_edge_clusters_id "edge-cluster")
        EDGEIDX01=$(get_edge_node_cluster_member_index "edge-cluster" "edge-1")
        EDGEIDX02=$(get_edge_node_cluster_member_index "edge-cluster" "edge-2")
        create_t0_interface "${T0GWNAME}" "${EDGECLUSTERID}" "${T0IP01}" "${T0SEGMENTNAME}" "${EDGEIDX01}" "edge-1-uplink-1"
        create_t0_interface "${T0GWNAME}" "${EDGECLUSTERID}" "${T0IP02}" "${T0SEGMENTNAME}" "${EDGEIDX02}" "edge-1-uplink-2"
else
        echo "  interfaces present"
fi

# configure cpodrouter bgp:
#
echo
echo checking bgp on cpodrouter
echo

ASNCPOD=$(get_cpod_asn ${CPOD_NAME_LOWER})
ASNNSXT=$((ASNCPOD + 1000))
CPODBGPTABLE=$(get_cpodrouter_bgp_neighbors_table ${CPOD_NAME_LOWER})
#test if already configured
IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP01})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP01} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP01}" "${ASNNSXT}" "${CPOD_NAME_LOWER}"
else
        echo "  ${T0IP01} already defined as bgp neighbor"
fi

IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP02})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP02} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP02}" "${ASNNSXT}" "${CPOD_NAME_LOWER}"
else
        echo "  ${T0IP02} already defined as bgp neighbor"
fi

# configure T0 bgp
# set AS number = cpodrouter + 1000
# save
# set neighbors
# add neighbor
# ip address : 10.vlan.4.1 - remote as number : cpodrouter asn

echo
echo "  Checking Tier 0 BGP"
echo

TOASN=$(get_tier-0s_bgp "${T0GWNAME}"  | jq .local_as_num)

if [ "${TOASN}" !=  "${ASNNSXT}" ]
then
        #set bgp
        configure_tier-0s_bgp "${T0GWNAME}" "${ASNNSXT}"
else
        echo "  Tier-0 BGP ASN already Set"
fi

echo
echo "  Checking BGP Neighbors"
echo

NEIGHBORS=$(get_tier-0s_bgp_neighbors  "${T0GWNAME}")

if [ "${NEIGHBORS}" == "" ]
then
        CPODASNIP="10.${VLAN}.4.1"
        configure_tier-0s_bgp_neighbor "${T0GWNAME}"  "${CPODASNIP}"  "${ASNCPOD}"  "${CPOD_NAME_LOWER}"
else
        echo "  BGP Neighbor present"
fi

# route redistribution
# set redistribution
# add route redistribution
# name: default - set route redistribution:
# T1 subnets : LB vip - nat ip - static routes - connected interfaces and segments

echo 

RULES=$(get_tier0_route_redistribution "${T0GWNAME}"  )
TESTBGP=$(echo "${RULES}" | jq -r .bgp_enabled )
if [ "${TESTBGP}" == "true" ]
then
        echo "  BGP redistribution already enabled"
        echo "  verifying rules"
        RULES=$(get_tier0_route_redistribution "${T0GWNAME}"  )
        TESTBGP=$(echo "${RULES}" | jq -r .redistribution_rules[] )

        if [ "${TESTBGP}" != "" ]
        then
                echo "  BGP redistribution rules are present"
        else
                echo "  enabling BGP redistribution and rules"
                patch_tier0_route_redistribution  "${T0GWNAME}"
        fi
else
        echo "  enabling BGP redistribution and rules"
        patch_tier0_route_redistribution  "${T0GWNAME}"
fi



#
# ===== NSX cleanup =====
# accept eula
# reject CEIP
# skip welcome tour

nsx_accept_eula
nsx_ceip_telemetry
nsx_ceip_agreement

# ===== Script finished =====
echo "Configuration done"
