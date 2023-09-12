#!/bin/bash
#edewitte@vmware.com

### NSX-T functions ####

# still needed ? source ./extra/functions.sh

# ========== NSX functions ===========

get_nsx_manager_status() {
        #returns json
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/cluster/status)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        case $HTTPSTATUS in

                200)    
                        echo ${RESPONSE} |awk -F '####' '{print $1}'  | jq -r .mgmt_cluster_status.status
                        ;;

                503)    
                        echo "Not Ready"
                        ;;
                *)      
                         echo ${RESPONSE} |awk -F '####' '{print $1}'
                        ;;

        esac
}

loop_wait_nsx_manager_status(){
        echo "  Checking nsx manager status"
        echo
        printf "\t connecting to nsx ."
        INPROGRESS=$(get_nsx_manager_status)
        CURRENTSTATE=${INPROGRESS}
        while [[ "$INPROGRESS" != "STABLE" ]]
        do      
                printf '.' >/dev/tty
                sleep 10
                INPROGRESS=$(get_nsx_manager_status)
                if [ "${INPROGRESS}" != "${CURRENTSTATE}" ] 
                then 
                        printf "\n\t%s" ${INPROGRESS}
                        CURRENTSTATE=${INPROGRESS}
                fi
        done
}

get_compute_manager() {
        # ${1} = compute manager name
        # returns json
        MGRNAME=${1}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${MANAGERSINFO}" > /tmp/mgr_json-$$
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
                echo "${MANAGERSINFO}" > /tmp/mgrid_json-$$
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
        SCRIPT="/tmp/CEIP_JSON-$$"
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
        SCRIPT="/tmp/CEIP_JSON-$$"
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
        "set_as_oidc_provider": true,
        "access_level_for_oidc": "FULL",
        "credential" : {
        "credential_type" : "UsernamePasswordLoginCredential",
        "username": "administrator@'${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
        "password": "'${PASSWORD}'",
        "thumbprint": "'${VCENTERTP}'"
        }
        }'
        SCRIPT="/tmp/CM_JSON-$$"
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
                echo $MGRINFO > /tmp/mgrstatus-json-$$ 
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
                INPROGRESS=$(echo "${MGRSTATUS}" | jq -r .connection_status)
        done

}

add_nsx_license() {
        LIC_JSON='{ "license_key": "'${LIC_NSXT}'" }'
        SCRIPT="/tmp/LIC_JSON-$$"
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
                echo "${PROFILESINFO}" > /tmp/profile-json-$$
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
                echo "${PROFILESINFO}" > /tmp/profile-json-$$
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
                echo "${PROFILESINFO}" > /tmp/profile-json-$$
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

        SCRIPT="/tmp/PROFILE_JSON-$$"
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
                echo "${TZINFO}" > /tmp/tz-json-$$
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
                echo "${TZINFO}" > /tmp/tz-json-$$
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
        SCRIPT="/tmp/TZ_JSON-$$"
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
                SCRIPT="/tmp/IPPOOL-${IPPOOLNAME}-$$"
                echo "${IPPOOLINFO}" > ${SCRIPT}
                IPPOOLCOUNT=$(echo ${IPPOOLINFO} | jq .result_count)                
                if [[ ${IPPOOLCOUNT} -gt 0 ]]
                then
                        echo $IPPOOLINFO |jq '.results[] | select (.display_name =="'$IPPOOLNAME'")'
                        IPPOOLID=$(echo $IPPOOLINFO |jq -r '.results[] | select (.display_name =="'$IPPOOLNAME'") | .id')
                        echo $IPPOOLID
                        check_ip_pool_subnet ${IPPOOLID}
                else
                        echo "  error getting IP Pool : $IPPOOLNAME"
                        echo ${HTTPSTATUS}
                        echo ${RESPONSE}
                        exit 1
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
                        echo "${IPPOOLINFO}" > /tmp/ippoolall-json-$$
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
                echo "  ${IPPOOLNAME} created succesfully"
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

        SCRIPT="/tmp/SUBNET_JSON-$$"
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
        UPLINK1="${7}"
        UPLINK2="${8}"
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
                "vds_uplink_name": "'${UPLINK1}'",
                "uplink_name": "uplink-1"
                },
                {
                "vds_uplink_name": "'${UPLINK2}'",
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

        SCRIPT="/tmp/TNPROFILE_JSON-$$"
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


create_transport_node_profile_old() {
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

        SCRIPT="/tmp/TNPROFILE_JSON-$$"
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

create_transport_node_profile_maz() {
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

        SCRIPT="/tmp/TNPROFILE_JSON-$$"
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

get_host_transport_node_profile_id_old() {
        #$1 transport zone name string
        #returns json and profile id
        HTNPROFILENAME=$1
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-transport-node-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                HTNPROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                HTNPROFILESCOUNT=$(echo $HTNPROFILESINFO | jq .result_count)
                echo $HTNPROFILESINFO > /tmp/htnp-json-$$ 
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

get_host_transport_node_profile_id() {
        #$1 transport zone name string
        #returns json and profile id
        HTNPROFILENAME=$1
        HTNPROFILEID=""
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-transport-node-profiles)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                HTNPROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                HTNPROFILESCOUNT=$(echo $HTNPROFILESINFO | jq .result_count)
                echo $HTNPROFILESINFO > /tmp/htnp-json-$$ 
                if [[ ${HTNPROFILESCOUNT} -gt 0 ]]
                then
                        EXISTINGTNPROFILES=$(echo $HTNPROFILESINFO | jq -r '.results[]  | select ( .display_name == "'${HTNPROFILENAME}'") | .display_name')
                        if [[ "${EXISTINGTNPROFILES}" == "${HTNPROFILENAME}" ]]
                        then
                                #echo "  host transport node profile set correctly : ${EXISTINGTNPROFILES}"
                                HTNPROFILEID=$(echo $HTNPROFILESINFO | jq -r '.results[]  | select ( .display_name == "'${HTNPROFILENAME}'") | .id')
                                echo "${HTNPROFILEID}"
                        fi
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
                echo ${CCINFO} > /tmp/ccinfo_id_json-$$
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
                echo ${CCINFO} > /tmp/ccinfo_eid_json-$$
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

get_compute_collection_local_id() {
        #$1 transport zone name string
        #returns json
        CLUSTERNAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-collections)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                CCINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo ${CCINFO} > /tmp/ccinfo_eid_json-$$
                CCCOUNT=$(echo ${CCINFO} | jq .result_count)
                if [[ ${CCCOUNT} -gt 0 ]]
                then
                        echo $CCINFO|  jq -r '.results[] | select ( .display_name == "'$CLUSTERNAME'" ) | .cm_local_id' 
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
                echo $TNCINFO > /tmp/tnc-json-$$ 
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
                echo $CCINFO > /tmp/htn-json-$$ 
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
                echo $CCINFO > /tmp/state-json-$$ 
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

        SCRIPT="/tmp/TNC_JSON-$$"
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

        SCRIPT="/tmp/SEGMENT_JSON-$$"
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
                echo $TNINFO > /tmp/edgenodes-json-$$ 
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
        CPODROUTERIP=${12}
        EDGEUPLINKTRUNK=${13}

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
                        "/infra/segments/'${EDGEUPLINKTRUNK}'-1",
                        "/infra/segments/'${EDGEUPLINKTRUNK}'-2"
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

        SCRIPT="/tmp/EDGE_JSON-$$"
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
                echo $NODESINFO > /tmp/edgenodes-list-json-$$ 
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
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json-$$ 
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

        SCRIPT="/tmp/EDGECLUSTER_JSON-$$"
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

create_edge_cluster_maz() {
        #$1 profile name string
        #$2 VLAN ID
        #returns json
        EDGECLUSTERNAME=$1
        EDGEID1=$2
        EDGEID2=$3
        EDGEID3=$4
        
        EDGECLUSTER_JSON='{
        "member_node_type": "EDGE_NODE",
        "resource_type": "EdgeCluster",
        "display_name": "'${EDGECLUSTERNAME}'",
        "deployment_type": "VIRTUAL_MACHINE",
        "members":  [
        {
                "transport_node_id": "'${EDGEID1}'"
        },
        {
                "transport_node_id": "'${EDGEID2}'"
        },
        {
                "transport_node_id": "'${EDGEID3}'"
        }
        ],
        "cluster_profile_bindings": [
                {
                "resource_type": "EdgeHighAvailabilityProfile",
                "profile_id": "91bcaa06-47a1-11e4-8316-17ffc770799b"
                }
        ]
        }'

        SCRIPT="/tmp/EDGECLUSTER_JSON-$$"
        echo ${EDGECLUSTER_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X POST -d @${SCRIPT} https://${NSXFQDN}/api/v1/edge-clusters)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        #echo $RESPONSE
        #echo $HTTPSTATUS

        if [ $HTTPSTATUS -eq 201 ]
        then
                EDGECLUSTERINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "${EDGECLUSTERINFO}" > /tmp/edge-cluster-created-json-$$
                EDGECLUSTERINFONAME=$(echo "${EDGECLUSTERINFO}" | jq -r '.results[] | select (.display_name == "'${EDGECLUSTERNAME}'") | .display_name')
                if [[ "${EDGECLUSTERINFONAME}" == "${EDGECLUSTERNAME}" ]]
                then
                        echo "  ${EDGECLUSTERNAME} created succesfully"
                else
                        echo "  ${EDGECLUSTERINFONAME} does not match ${EDGECLUSTERNAME}"
                        exit 1
                fi
        else
                echo "  error creating edge cluster  : ${EDGECLUSTERNAME}"
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
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json-$$ 
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

        SCRIPT="/tmp/SEGMENT_JSON-$$"
        echo ${SEGMENT_JSON} > ${SCRIPT}
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD}  -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/segments/${SEGMENTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
        if [ $HTTPSTATUS -eq 200 ]
        then
                SEGMENTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${SEGMENTNAME} created succesfully"
                echo ${SEGMENTINFO} > /tmp/t0-segment-create.json-$$
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
                echo $T0INFO > /tmp/t0-json-$$ 
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
                echo ${T0GWINFO} > /tmp/t0-gw-create.json-$$

        else
                echo "  error creating T0 GW : ${T0NAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_locale_services(){
                #
        T0NAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0COUNT=$(echo ${T0INFO} | jq .result_count)
                echo $T0INFO > /tmp/t0-local_services-json-$$ 
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

get_tier-0s_locale_services_name(){
                #
        T0NAME=$1

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0COUNT=$(echo ${T0INFO} | jq .result_count)
                echo $T0INFO > /tmp/t0-local_services-json-$$ 
                if [[ ${T0COUNT} -gt 0 ]]
                then
                        echo "${T0INFO}" |jq -r .results[].display_name
                else
                        echo ""
                fi
        else
                echo "  error getting Tier-0s : ${T0NAME} locale_services"
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
        SCRIPT="/tmp/T0_LS_JSONDEPS_ID-$$"
        echo ${T0_LS_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0GWINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${T0NAME} created succesfully"
                echo ${T0GWINFO} > /tmp/t0-ls-create.json-$$

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
                echo $T0INTINFO > /tmp/t0-interfaces-json-$$ 
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

get_tier-0s_interfaces_v2(){
        #https://${NSXFQDN}/policy/api/v1/infra/tier-0s/Tier-0/locale-services/default/interfaces
        T0NAME=$1
        LOCALESERVICE=$2
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE}/interfaces)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                T0INTCOUNT=$(echo ${T0INTINFO} | jq .result_count)
                echo $T0INTINFO > /tmp/t0-interfaces-json-$$ 
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
                echo $EDGECLUSTERSINFO > /tmp/edge-clusters-json-$$ 
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
        SCRIPT="/tmp/T0_INT_JSON-$$"
        echo ${T0_INT_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/interfaces/${INTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${INTNAME} created succesfully"
                echo ${T0INTINFO} > /tmp/t0-int-create.json-$$

        else
                echo "  error creating T0 interface : ${INTNAME} "
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

create_t0_interface_v2() {
        #
        T0NAME=$1
        EDGECLUSTERID=$2
        INTIP=$3
        SEGMENT=$4
        EDGENODEIDX=$5
        INTNAME=$6
        LOCALESERVICE=$7

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
        SCRIPT="/tmp/T0_INT_JSON-$$"
        echo ${T0_INT_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE}/interfaces/${INTNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                T0INTINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo "  ${INTNAME} created succesfully"
                echo ${T0INTINFO} > /tmp/t0-int-create.json-$$

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
                echo $BGPINFO > /tmp/t0-bgp-json-$$ 
                echo "${BGPINFO}" 
        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_bgp_v2(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        LOCALESERVICE=$2
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE}/bgp)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-json-$$ 
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
        SCRIPT="/tmp/T0_BGP_JSON-$$"
        echo ${T0_BGP_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-configured-json-$$ 
                echo "  BGP Enabled succesfully with ASN : ${ASNNUMBER}" 
        else
                echo "  error configuring Tier-0s BGP"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}


configure_tier-0s_bgp_v2(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        ASNNUMBER=$2
        LOCALSERVICE=$3

        T0_BGP_JSON='{
        "local_as_num": "'${ASNNUMBER}'",
        "enabled": true
        }'
        SCRIPT="/tmp/T0_BGP_JSON-$$"
        echo ${T0_BGP_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALSERVICE}/bgp)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-configured-json-$$ 
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
                echo $BGPINFO > /tmp/t0-bgp-neighbors-json-$$ 
                echo "${BGPINFO}" | jq .results[]
        else
                echo "  error getting Tier-0s"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier-0s_bgp_neighbors_v2(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        LOCALESERVICE=$2
        
        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE}/bgp/neighbors)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                BGPINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $BGPINFO > /tmp/t0-bgp-neighbors-json-$$ 
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
        SCRIPT="/tmp/T0_NB_JSON-$$"
        echo ${T0_NB_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default/bgp/neighbors/${NBNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json-$$ 
                echo "  BGP Neighbor ${NBNAME} added successully" 
        else
                echo "  error configuring Tier-0s BGP Neighbor ${$NBNAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

configure_tier-0s_bgp_neighbor_v2(){
        
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        NBIP=$2
        NBASN=$3
        NBNAME=$4
        LOCALESERVICE=$5
        SOURCEADDRESS=$6

        T0_NB_JSON='{
        "neighbor_address": "'${NBIP}'",
        "source_addresses": [ "'${SOURCEADDRESS}'" ],
        "remote_as_num": "'${NBASN}'"
        }'
        SCRIPT="/tmp/T0_NB_JSON-$$"
        echo ${T0_NB_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE}/bgp/neighbors/${NBNAME})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json-$$ 
                echo "  BGP Neighbor ${NBNAME} added successully" 
        else
                echo "  error configuring Tier-0s BGP Neighbor ${NBNAME}"
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
                echo $LRINFO > /tmp/logical-routers-json-$$ 
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
                echo $LRINFO > /tmp/logical-routers-redist-json-$$ 
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
                echo $LRINFO > /tmp/logical-routers-redist-json-$$ 
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
        SCRIPT="/tmp/T0_LR_JSON-$$"
        echo ${T0_LR_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution )
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-redist-configured-json-$$ 
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
                echo $LRINFO > /tmp/logical-routers-redist-rules-json-$$ 
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
                echo $LRINFO > /tmp/logical-routers-redist-rules-json-$$ 
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
        SCRIPT="/tmp/T0_RDST_RULES_JSON-$$"
        echo ${T0_RDST_RULES_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PUT -d @${SCRIPT} https://${NSXFQDN}/api/v1/logical-routers/${LRID}/routing/redistribution/rules )
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-redist-rules-configured-json-$$ 
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
                echo "  error getting Tier-0s ${T0NAME} route_redistribution_config"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
}

get_tier0_route_redistribution_v2() {
 #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        LOCALESERVICE=$2

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                ROUTEINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                ROUTEREDIST=$(echo ${ROUTEINFO} | jq .route_redistribution_config)
        else
                echo "  error getting Tier-0s ${T0NAME} route_redistribution_config"
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
        SCRIPT="/tmp/T0_RULES_JSON-$$"
        echo ${T0_RULES_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PATCH -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/default)
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json-$$ 
                echo "  patch_tier0_route_redistribution ${T0NAME} successul" 
        else
                echo "  error patch_tier0_route_redistribution ${T0NAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
        
}

patch_tier0_route_redistribution_v2() {
        #/infra/tier-0s/Tier-0/locale-services/default/bgp/neighbors/071971c8-4229-439f-bcdb-6f0378510b11
        T0NAME=$1
        LOCALESERVICE=$2

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
        SCRIPT="/tmp/T0_RULES_JSON-$$"
        echo ${T0_RULES_JSON} > ${SCRIPT}

        RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} -H 'Content-Type: application/json' -X PATCH -d @${SCRIPT} https://${NSXFQDN}/policy/api/v1/infra/tier-0s/${T0NAME}/locale-services/${LOCALESERVICE})
        HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

        if [ $HTTPSTATUS -eq 200 ]
        then
                NBINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
                echo $NBINFO > /tmp/t0-bgp-nb-configured-json-$$ 
                echo "  patch_tier0_route_redistribution_v2 ${T0NAME} successul " 
        else
                echo "  error patch_tier0_route_redistribution_v2 ${T0NAME}"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
        
}

###################