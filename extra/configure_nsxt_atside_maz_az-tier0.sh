#!/bin/bash
#edewitte@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod MAZ Mgmt Name>  <cPod MAZ AZ1 Name> <cPod MAZ AZ2 Name> <cPod MAZ AZ3 Name> <owner email>" && exit 1

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

###################

### functions ####

source ./extra/functions.sh
source ./extra/functions_nsxt.sh

###################

echo
echo "============================"
echo "=== Checking CPODs exist ==="
echo "============================"
echo

SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
[ $? -ne 0 ] && echo "error: cpod '${1}' does not exist" && exit 1
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${2} )
[ $? -ne 0 ] && echo "error: cpod '${2}' does not exist" && exit 1
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${3} )
[ $? -ne 0 ] && echo "error: cpod '${3}' does not exist" && exit 1
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${4} )
[ $? -ne 0 ] && echo "error: cpod '${4}' does not exist" && exit 1
SUBNET=""


###################
#MGMT CPOD
CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"

#AZ1 CPOD
AZ1CPOD_NAME="cpod-$2"
AZ1NAME_HIGHER=$( echo ${2} | tr '[:lower:]' '[:upper:]' )
AZ1NAME_LOWER=$( echo ${2} | tr '[:upper:]' '[:lower:]' )

AZ1CPOD_NAME_LOWER=$( echo ${AZ1CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
AZ1CPOD_PORTGROUP="${AZ1CPOD_NAME_LOWER}"

AZ1SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${2} )

AZ1CPODROUTERIP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ${AZ1CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)

#AZ2 CPOD
AZ2CPOD_NAME="cpod-$3"
AZ2NAME_HIGHER=$( echo ${3} | tr '[:lower:]' '[:upper:]' )
AZ2NAME_LOWER=$( echo ${3} | tr '[:upper:]' '[:lower:]' )

AZ2CPOD_NAME_LOWER=$( echo ${AZ2CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
AZ2CPOD_PORTGROUP="${AZ2CPOD_NAME_LOWER}"

AZ2SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${3} )

AZ2CPODROUTERIP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ${AZ2CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)

#AZ3 CPOD
AZ3CPOD_NAME="cpod-$4"
AZ3NAME_HIGHER=$( echo ${4} | tr '[:lower:]' '[:upper:]' )
AZ3NAME_LOWER=$( echo ${4} | tr '[:upper:]' '[:lower:]' )

AZ3CPOD_NAME_LOWER=$( echo ${AZ3CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
AZ3CPOD_PORTGROUP="${AZ3CPOD_NAME_LOWER}"

AZ3SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${4} )

AZ3CPODROUTERIP=$(ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ${AZ3CPOD_NAME} "ip add | grep inet | grep eth0" | awk '{print $2}' | cut -d "/" -f 1)

NSXFQDN="nsx.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
echo ${NSXFQDN}

AZ1VLAN=$( grep -m 1 "${AZ1CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
AZ2VLAN=$( grep -m 1 "${AZ2CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
AZ3VLAN=$( grep -m 1 "${AZ3CPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

if [ ${AZ1VLAN} -gt 40 ]; then
	AZ1TEPVLANID=${AZ1VLAN}3
        AZ1UPLINKSVLANID=${AZ1VLAN}4
else
	AZ1TEPVLANID=${AZ1VLAN}03
        AZ1UPLINKSVLANID=${AZ1VLAN}04
fi

if [ ${AZ2VLAN} -gt 40 ]; then
	AZ2TEPVLANID=${AZ2VLAN}3
        AZ2UPLINKSVLANID=${AZ2VLAN}4
else
	AZ2TEPVLANID=${AZ2VLAN}03
        AZ2UPLINKSVLANID=${AZ2VLAN}04
fi

if [ ${AZ3VLAN} -gt 40 ]; then
	AZ3TEPVLANID=${AZ3VLAN}3
        AZ3UPLINKSVLANID=${AZ3VLAN}4
else
	AZ3TEPVLANID=${AZ3VLAN}03
        AZ3UPLINKSVLANID=${AZ3VLAN}04
fi


PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# get govc env for cpod
./extra/govc_cpod.sh  ${NAME_LOWER}  2>&1 > /dev/null
GOVCSCRIPT=/tmp/scripts/govc_${CPOD_NAME_LOWER}
source ${GOVCSCRIPT}


# ===== Start of code =====

# ===== create edge cluster =====
# create edge cluster and add nodes to it

echo
echo "Checking Edge Clusters"
echo
MAZEDGECLUSTERNAME="maz-edgecluster"
EDGECLUSTERS=$(get_edge_clusters)
if [ "${EDGECLUSTERS}" != "" ];
then
        echo "  Edge Clusters exist"
else
        EDGEID1=$(get_transport_node "edge-${AZ1NAME_LOWER}")
        EDGEID2=$(get_transport_node "edge-${AZ2NAME_LOWER}")
        EDGEID3=$(get_transport_node "edge-${AZ3NAME_LOWER}")
        create_edge_cluster_maz "${MAZEDGECLUSTERNAME}" $EDGEID1 $EDGEID2 $EDGEID3
fi

# ===== create nsx segments for T0 =====
# name: t0-uplink-1 - no gw - tz : edge-vlan-tz - teaming : edge-uplink-1 - vlan id : VLAN#4 (uplinks)
echo
echo "Processing T0 segment"
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


T0AZ1SEGMENTNAME="maz-t0-az1-ls"

if [ "$(get_segment "${T0AZ1SEGMENTNAME}")" == "" ]
then
        echo "get_transport_zone_id : ${AZ1NAME_LOWER}-edge-vlan-tz"
        TZID=$(get_transport_zone_id "${AZ1NAME_LOWER}-edge-vlan-tz")
        echo "TZID : ${TZID}"
        if [[ "${TZID}" != *"error"* ]] || [ "${TZID}" != "" ];
        then
                create_t0_segment "${T0AZ1SEGMENTNAME}" "$TZID" "${AZ1NAME_LOWER}-edge-profile-uplink-1" "${AZ1UPLINKSVLANID}"
        else
                echo " error getting transport_zone_id ${AZ1NAME_LOWER}-edge-vlan-tz"
                exit 1
        fi
else
        echo "  ${T0AZ1SEGMENTNAME} - present"
fi

T0AZ2SEGMENTNAME="maz-t0-az2-ls"

if [ "$(get_segment "${T0AZ2SEGMENTNAME}")" == "" ]
then
        echo "get_transport_zone_id : ${AZ2NAME_LOWER}-edge-vlan-tz"
        TZID=$(get_transport_zone_id "${AZ2NAME_LOWER}-edge-vlan-tz")
        echo "TZID : ${TZID}"
        if [[ "${TZID}" != *"error"* ]] || [ "${TZID}" != "" ];
        then
                create_t0_segment "${T0AZ2SEGMENTNAME}" "$TZID" "${AZ2NAME_LOWER}-edge-profile-uplink-1" "${AZ2UPLINKSVLANID}"
        else
                echo " error getting transport_zone_id ${AZ2NAME_LOWER}-edge-vlan-tz"
                exit 1
        fi

else
        echo "  ${T0AZ2SEGMENTNAME} - present"
fi

T0AZ3SEGMENTNAME="maz-t0-az3-ls"

if [ "$(get_segment "${T0AZ3SEGMENTNAME}")" == "" ]
then
        echo "get_transport_zone_id : ${AZ3NAME_LOWER}-edge-vlan-tz"
        TZID=$(get_transport_zone_id "${AZ3NAME_LOWER}-edge-vlan-tz")
        echo "TZID : ${TZID}"
        if [[ "${TZID}" != *"error"* ]] || [ "${TZID}" != "" ];
        then
                create_t0_segment "${T0AZ3SEGMENTNAME}" "$TZID" "${AZ3NAME_LOWER}-edge-profile-uplink-1" "${AZ3UPLINKSVLANID}"
        else
                echo " error getting transport_zone_id ${AZ3NAME_LOWER}-edge-vlan-tz"
                exit 1
        fi

else
        echo "  ${T0AZ3SEGMENTNAME} - present"
fi

# ===== create T0 =====
# create TO in network - T0 gateways
# name : Tier-0 - HA mode : active-active - edge cluster : edge-cluster
# save
echo
echo "Processing T0 gateway"
echo

T0GWNAME="MAZ-Tier-0"

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
        EDGECLUSTERID=$(get_edge_clusters_id "${MAZEDGECLUSTERNAME}")
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

T0IP01="10.${AZ1VLAN}.4.11"
T0IP02="10.${AZ2VLAN}.4.11"
T0IP03="10.${AZ3VLAN}.4.11"

INTERFACES=$(get_tier-0s_interfaces  "${T0GWNAME}")

if [ "${INTERFACES}" == "" ]
then
        EDGECLUSTERID=$(get_edge_clusters_id "${MAZEDGECLUSTERNAME}")
        EDGEIDX01=$(get_edge_node_cluster_member_index "${MAZEDGECLUSTERNAME}" "edge-${AZ1NAME_LOWER}")
        EDGEIDX02=$(get_edge_node_cluster_member_index "${MAZEDGECLUSTERNAME}" "edge-${AZ2NAME_LOWER}")
        EDGEIDX03=$(get_edge_node_cluster_member_index "${MAZEDGECLUSTERNAME}" "edge-${AZ2NAME_LOWER}")

        create_t0_interface "${T0GWNAME}" "${EDGECLUSTERID}" "${T0IP01}" "${T0AZ1SEGMENTNAME}" "${EDGEIDX01}" "edge-az1-uplink-1"
        create_t0_interface "${T0GWNAME}" "${EDGECLUSTERID}" "${T0IP02}" "${T0AZ2SEGMENTNAME}" "${EDGEIDX02}" "edge-az2-uplink-1"
        create_t0_interface "${T0GWNAME}" "${EDGECLUSTERID}" "${T0IP03}" "${T0AZ3SEGMENTNAME}" "${EDGEIDX03}" "edge-az3-uplink-1"
        
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

#Configure AZ1
CPODBGPTABLE=$(get_cpodrouter_bgp_neighbors_table ${AZ1CPOD_NAME_LOWER})
#test if already configured
IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP01})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP01} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP01}" "${ASNNSXT}" "${AZ1CPOD_NAME_LOWER}"
else
        echo "  ${T0IP01} already defined as bgp neighbor"
fi

#Configure AZ2
CPODBGPTABLE=$(get_cpodrouter_bgp_neighbors_table ${AZ2CPOD_NAME_LOWER})
#test if already configured
IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP02})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP02} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP02}" "${ASNNSXT}" "${AZ2CPOD_NAME_LOWER}"
else
        echo "  ${T0IP02} already defined as bgp neighbor"
fi

#Configure AZ3
CPODBGPTABLE=$(get_cpodrouter_bgp_neighbors_table ${AZ3CPOD_NAME_LOWER})
#test if already configured
IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP03})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP02} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP03}" "${ASNNSXT}" "${AZ2CPOD_NAME_LOWER}"
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
        LOCALESERVICE=$(get_tier-0s_locale_services_name "${T0GWNAME}")
        if  [[ "${LOCALESERVICE}" == *"error"* ]] || [ "${LOCALESERVICE}" !=  "" ]
        then
                configure_tier-0s_bgp_v2 "${T0GWNAME}" "${ASNNSXT}" "${LOCALESERVICE}"
        else
                echo " error getting get_tier-0s_locale_services_name ${T0GWNAME}"
                exit
        fi
else
        echo "  Tier-0 BGP ASN already Set"
fi

echo
echo "  Checking BGP Neighbors"
echo

NEIGHBORS=$(get_tier-0s_bgp_neighbors  "${T0GWNAME}")

if [ "${NEIGHBORS}" == "" ]
then
        #AZ1
        AZ1CPODASNIP="10.${AZ1VLAN}.4.1"
        AZ1ASNCPOD=$(get_cpod_asn ${AZ1CPOD_NAME_LOWER})
        configure_tier-0s_bgp_neighbor_v2 "${T0GWNAME}"  "${AZ1CPODASNIP}"  "${AZ1ASNCPOD}"  "${AZ1CPOD_NAME_LOWER}" "${LOCALESERVICE}"
        #AZ2
        AZ2CPODASNIP="10.${AZ2VLAN}.4.1"
        AZ2ASNCPOD=$(get_cpod_asn ${AZ2CPOD_NAME_LOWER})
        configure_tier-0s_bgp_neighbor_v2 "${T0GWNAME}"  "${AZ2CPODASNIP}"  "${AZ2ASNCPOD}"  "${AZ2CPOD_NAME_LOWER}" "${LOCALESERVICE}"
        #AZ3
        AZ3CPODASNIP="10.${AZ3VLAN}.4.1"
        AZ3ASNCPOD=$(get_cpod_asn ${AZ1CPOD_NAME_LOWER})
        configure_tier-0s_bgp_neighbor_v2 "${T0GWNAME}"  "${AZ3CPODASNIP}"  "${AZ3ASNCPOD}"  "${AZ3CPOD_NAME_LOWER}" "${LOCALESERVICE}"

else
        echo "  BGP Neighbors present on ${T0GWNAME}"
fi

# route redistribution
# set redistribution
# add route redistribution
# name: default - set route redistribution:
# T1 subnets : LB vip - nat ip - static routes - connected interfaces and segments

echo 

RULES=$(get_tier0_route_redistribution_v2 "${T0GWNAME}"  "${LOCALESERVICE}" )
TESTBGP=$(echo "${RULES}" | jq -r .bgp_enabled )
if [ "${TESTBGP}" == "true" ]
then
        echo "  BGP redistribution already enabled"
        echo "  verifying rules"
        RULES=$(get_tier0_route_redistribution_v2 "${T0GWNAME}" "${LOCALESERVICE}" )
        TESTBGP=$(echo "${RULES}" | jq -r .redistribution_rules[] )

        if [ "${TESTBGP}" != "" ]
        then
                echo "  BGP redistribution rules are present"
        else
                echo "  enabling BGP redistribution and rules"
                patch_tier0_route_redistribution_v2  "${T0GWNAME}" "${LOCALESERVICE}"
        fi
else
        echo "  enabling BGP redistribution and rules"
        patch_tier0_route_redistribution_v2  "${T0GWNAME}" "${LOCALESERVICE}"
fi

# ===== Script finished =====
echo "Configuration done"