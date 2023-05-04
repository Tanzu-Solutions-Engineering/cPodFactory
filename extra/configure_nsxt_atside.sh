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

add_computer_manager() {
        CM_JSON='{
        "server": "'vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
        "display_name": "'vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}'",
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
                #echo ${MANAGERSINFO}
                MANAGERSRV=$(echo $MANAGERSINFO | jq -r .server)
                echo "  Compute Manager added succesfully = ${MANAGERSRV}"
        else
                echo "  error setting manager"
                echo ${HTTPSTATUS}
                echo ${RESPONSE}
                exit
        fi
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
                echo $PROFILESINFO |jq -r '.results[] | select (.display_name =="'$PROFILENAME'") | .id'
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
        "id": "'$PROFILENAME'",
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
                "ip_pool_id": "/infra/manager-ip-pools/'${IPPOOLID}'",
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
###################


CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
VMNAME="${VAPP}-${HOSTNAME}"

VLAN=$( grep -m 1 "${CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

if [ ${VLAN} -gt 40 ]; then
	VMOTIONVLANID=${VLAN}1
	VSANVLANID=${VLAN}2
	TEPVLANID=${VLAN}3
else
	VMOTIONVLANID=${VLAN}01
	VSANVLANID=${VLAN}02
	TEPVLANID=${VLAN}03
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
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/api/v1/fabric/compute-managers)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        MANAGERSINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        MANAGERSCOUNT=$(echo $MANAGERSINFO | jq .result_count)
        if [[ ${MANAGERSCOUNT} -gt 0 ]]
        then
                EXISTINGMNGR=$(echo $MANAGERSINFO| jq -r .results[0].server)
                if [[ "${EXISTINGMNGR}" == "vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}" ]]
                then
                        echo "  existing manager set correctly : ${EXISTINGMNGR}"
                else
                        echo "  ${EXISTINGMNGR} does not match vcsa.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
                fi
        else
                echo "  adding compute manager"
                add_computer_manager
        fi
else
        echo "  error getting managers"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
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
VDSUUID=$(govc find / -type DistributedVirtualSwitch | xargs -n1 govc dvs.portgroup.info | grep DvsUuid | uniq | cut -d":" -f2 | awk '{$1=$1;print}')
echo "  VDS UUID : ${VDSUUID}"
if [ "${VDSUUID}" == "" ]
then
        echo "  problem getting VDS UUID"
        exit
fi
#get Host Profile ID
HOSTPROFILEID=$(get_uplink_profile_id "host-profile")
echo "  HOST Profile ID: ${HOSTPROFILEID}"
get_uplink_profile_id "host-profile"

#get transport zones ids
HOSTTZID=$(get_transport_zone_id "host-vlan-tz")
echo "  HOST TZ ID: ${HOSTTZID}"
OVERLAYTZID=$(get_transport_zone_id "overlay-tz")
echo "  OVERLAY TZ ID: ${OVERLAYTZID}"

#GET IP POOL ID
IPPOOLID=$(get_ip_pool_id "TEP-pool")
echo "  IP POOL ID : ${IPPOOLID}"
TNPROFILENAME="cluster-transport-node-profile"

get_ip_pool_all

echo "  Checking Transport Nodes Profile"
RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/host-transport-node-profiles)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        TNPROFILESINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        TNPROFILESCOUNT=$(echo $TNPROFILESINFO | jq .result_count)
        if [[ ${TNPROFILESCOUNT} -gt 0 ]]
        then
                echo ${TNPROFILESINFO} |jq .
                
                EXISTINGTNPROFILES=$(echo $TNPROFILESINFO| jq -r .results[0].display_name)

                if [[ "${EXISTINGTNPROFILES}" == "${TNPROFILENAME}" ]]
                then
                        echo "  existing transport node profile set correctly : ${EXISTINGTNPROFILES}"
                else
                        echo "  ${EXISTINGTNPROFILES} does not match ${TNPROFILENAME}"
                        echo "  stopping here"
                        exit
                fi
        else
                echo "  adding TN PROFILES"
                #add_tn_profiles
                create_transport_node_profile "${TNPROFILENAME}" "${VDSUUID}" "${HOSTTZID}" "${OVERLAYTZID}" "${IPPOOLID}" "${HOSTPROFILEID}"
        fi
else
        echo "  error getting transport node profile"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

exit
# ===== Configure NSX on ESX hosts =====

#/policy/api/v1/infra/sites/{site-id}/enforcement-points/{enforcementpoint-id}/host-transport-nodes


RESPONSE=$(curl -s -k -w '####%{response_code}' -u admin:${PASSWORD} https://${NSXFQDN}/policy/api/v1/infra/sites/default/enforcement-points/${EXISTINGEPRP}/host-transport-nodes)
HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')

if [ $HTTPSTATUS -eq 200 ]
then
        HTNINFO=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
        HTNCOUNT=$(echo ${HTNINFO} | jq .result_count)
        if [[ ${HTNCOUNT} -gt 0 ]]
        then
                EXISTINGHTN=$(echo $HTNINFO| jq -r '.results[].node_deployment_inf.fqdn')
                echo $EXISTINGHTN
                if [[ "${EXISTINGHTN}" == "blahblah" ]]
                then
                        echo "existing manager set correctly"
                else
                        echo " ${EXISTINGHTN} does not match blahblah"
                        echo ${HTNINFO}
                fi
        else
                echo "TODO : add host transport nodes"

                exit
        fi
else
        echo "  error getting uplink profiles"
        echo ${HTTPSTATUS}
        echo ${RESPONSE}
        exit
fi

# ===== create nsx segments for edge vms =====
# edge-uplink-trunk-1 - tz = host-vlan-tz - teaming policy : host-uplink-1 - vlan : 0-4094
# edge-uplink-trunk-2 - tz = host-vlan-tz - teaming policy : host-uplink-2 - vlan : 0-4094



# ===== create edge nodes =====
# edge-1 - fqdn : edge-1.cpod... - size : large 
# set password
# allow ssh for admin
# set computer manager: vcenter - cluster - datastore : vsandatastore
# node settings : ip : mgmt.54/24 - GW - Portgroup (vm network / vds pg : mgmt - search domain - dns - ntp )
# "configure nsx" - "new node switch" - switch name nsxHostSwitch - TZ : edge-vlan-tz + overlay-tz - uplink : edge-profile - ip assignment : ip pool - ip pool : TEP-pool - /
#    teaming policy uplink mapping : type "vlan segment" : "edge-uplink-trunk-1" / 2


# deploy edge code here


# check edge node status - Not Available -> ready  in "configuration state" - "Registration Pending" - Success



# ===== create edge cluster =====
# create edge cluster and add nodes to it


# ===== create nsx segments for T0 =====
# name: t0-uplink-1 - no gw - tz : edge-vlan-tz - teaming : edge-uplink-1 - vlan id : VLAN#4 (uplinks)


# ===== create T0 =====
# create TO in network - T0 gateways
# name : Tier-0 - HA mode : active-active - edge cluster : edge-cluster
# save
# set interfaces
# add interfce
# name : edge-1-uplink-1 - type : external - ip : 10.vlan.4.11 - segment : t0-uplink-1 - edge node : edge-1
# add interfce
# name : edge-2-uplink-2 - type : external - ip : 10.vlan.4.12 - segment : t0-uplink-1 - edge node : edge-2


# configure cpodrouter bgp:
#
# cpodrouter-nsxtv3# configure terminal
# cpodrouter-nsxtv3(config)# router bgp 65934
# cpodrouter-nsxtv3(config-router)# neighbor 10.134.4.11 remote-as 66934
# cpodrouter-nsxtv3(config-router)# neighbor 10.134.4.11 default-originate
# cpodrouter-nsxtv3(config-router)# do write memory
# 

# configure T0 bgp
# set AS number = cpodrouter + 1000
# save
# set neighbors
# add neighbor
# ip address : 10.vlan.4.1 - remote as number : cpodrouter asn

# route redistribution
# set redistribution
# add route redistribution
# name: default - set route redistribution:
# T1 subnets : LB vip - nat ip - static routes - connected interfaces and segments



# ===== Script finished =====
echo "Configuration done"
