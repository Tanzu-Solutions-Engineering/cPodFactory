#!/bin/bash
#edewitte@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod MAZ Mgmt Name>  <cPod MAZ AZ Name> <owner email>" && exit 1

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
SUBNET=""


###################
#MGMT CPOD
CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
CPOD_PORTGROUP="${CPOD_NAME_LOWER}"

#AZ CPOD
AZCPOD_NAME="cpod-$2"
AZNAME_HIGHER=$( echo ${2} | tr '[:lower:]' '[:upper:]' )
AZNAME_LOWER=$( echo ${2} | tr '[:upper:]' '[:lower:]' )

AZCPOD_NAME_LOWER=$( echo ${AZCPOD_NAME} | tr '[:upper:]' '[:lower:]' )
AZCPOD_PORTGROUP="${AZCPOD_NAME_LOWER}"

NSXFQDN="nsx.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
echo ${NSXFQDN}

AZVLAN=$( grep -m 1 "${AZCPOD_NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )

if [ ${AZVLAN} -gt 40 ]; then
	TEPVLANID=${AZVLAN}3
        UPLINKSVLANID=${AZVLAN}4
else
	TEPVLANID=${AZVLAN}03
        UPLINKSVLANID=${AZVLAN}04
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

# get govc env for cpod
./extra/govc_cpod.sh  ${NAME_LOWER}  2>&1 > /dev/null
GOVCSCRIPT=/tmp/scripts/govc_${CPOD_NAME_LOWER}
source ${GOVCSCRIPT}

AZCLuster=$(govc find . -type c |grep "${AZCPOD_NAME_LOWER}")

# ===== Start of code =====

# ===== Create Uplink profiles =====
# Check existing uplink profiles
# 1 for edge
# 1 for hosts
echo
echo "processing uplink profiles"
echo

EDGE=$(check_uplink_profile "${AZNAME_LOWER}-edge-profile")
#echo "uplink profile edge : ${EDGE}" 
if [[ "${EDGE}" == *"error"* ]] || [[ "${EDGE}" == "" ]] 
then
        echo "  create ${AZNAME_LOWER}-edge-profile"
        create_uplink_profile "${AZNAME_LOWER}-edge-profile" $TEPVLANID
else 
        echo "  ${AZNAME_LOWER}-edge-profile exists"
        #echo $EDGE
fi

HOST=$(check_uplink_profile "${AZNAME_LOWER}-host-profile")
#echo "uplink profile edge : ${HOST}" 
if [[ "${HOST}" == *"error"* ]] || [[ "${HOST}" == "" ]] 
then
        echo "  create ${AZNAME_LOWER}-host-profile"
        create_uplink_profile "${AZNAME_LOWER}-host-profile" $TEPVLANID
else 
        echo "  ${AZNAME_LOWER}-host-profile exists"
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

EDGE=$(check_transport_zone "${AZNAME_LOWER}-edge-vlan-tz")
if [[ "${EDGE}" == *"error"* ]]  || [[ "${EDGE}" == "" ]] 
then
        echo "  create check_transport_zone "${AZNAME_LOWER}-edge-vlan-tz""
        create_transport_zone "${AZNAME_LOWER}-edge-vlan-tz" "VLAN_BACKED" "${AZNAME_LOWER}-edge-profile"
else 
        echo "  ${AZNAME_LOWER}-edge-vlan-tz exists"
        #echo $EDGE
fi

HOST=$(check_transport_zone "${AZNAME_LOWER}-host-vlan-tz")
if [[ "${HOST}" == *"error"* ]]  || [[ "${HOST}" == "" ]] 
then
        echo "  create check_transport_zone ${AZNAME_LOWER}-host-vlan-tz"
        create_transport_zone "${AZNAME_LOWER}-host-vlan-tz" "VLAN_BACKED" "${AZNAME_LOWER}-host-profile"
else 
        echo "  ${AZNAME_LOWER}-host-vlan-tz exists"
        #echo $HOST
fi

OVERLAY=$(check_transport_zone "overlay-tz")
if [[ "${OVERLAY}" == *"error"* ]]  || [[ "${OVERLAY}" == "" ]] 
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
echo
POOL=$(check_ip_pool "${AZNAME_LOWER}-TEP-pool")
#echo "${POOL}"
if [[ "${POOL}" == *"error"* ]] || [[ "${POOL}" == "" ]] 
then
        echo "  create ${AZNAME_LOWER}- TEP IP pool"
        create_ip_pool "${AZNAME_LOWER}-TEP-pool" "${AZNAME_LOWER}-TEP-pool-subnet"  "10.${AZVLAN}.3.2" "10.${AZVLAN}.3.200" "10.${AZVLAN}.3.0/24"  "10.${AZVLAN}.3.1" 
else 
        echo "  ${AZNAME_LOWER}-TEP-pool exists"
fi

# ===== transport node profile =====
# Check existing transport node profile

echo
echo "Processing Transport Node"
echo


# VDS UUID
# govc ls -json=true network |jq -r '.elements[] | select ( .Object.Summary.ProductInfo.Name == "DVS") |  .Object.Summary.Uuid'

#VDSUUID=$(govc find / -type DistributedVirtualSwitch | xargs -n1 govc dvs.portgroup.info | grep DvsUuid | uniq | cut -d":" -f2 | awk '{$1=$1;print}')
VDSUUID=$(govc ls -json=true network |jq -r '.elements[] | select ( .Object.Summary.ProductInfo.Name == "DVS" and .Object.Summary.Name == "dvs-'${AZCPOD_NAME_LOWER}'") |  .Object.Summary.Uuid')
echo "  VDS UUID : ${VDSUUID}"
if [ "${VDSUUID}" == "" ]
then
        echo "  problem getting VDS UUID"
        exit
fi

echo "Getting VDS uplinks"
readarray -t VDSUPLINKS < <(govc ls -json=true network |jq -r '.elements[] | select ( .Object.Summary.ProductInfo.Name == "DVS" and .Object.Summary.Name == "dvs-'${AZCPOD_NAME_LOWER}'") |  .Object.Config.UplinkPortPolicy.UplinkPortName')
echo "  VDS UPLINKS : " 
echo "${VDSUPLINKS[@]}"
if [ "${VDSUPLINKS}" == "" ]
then
        echo "  problem getting VDS uplinks"
        exit
fi

#get Host Profile ID
HOSTPROFILEID=$(get_uplink_profile_id "${AZNAME_LOWER}-host-profile")
if [[ "${HOSTPROFILEID}" == *"error"* ]] || [ "${HOSTPROFILEID}" == "" ]
then
        echo "  problem getting Host Profile ID : ${AZNAME_LOWER}-host-profile"
        exit
else
        echo "  HOST Profile ID: ${HOSTPROFILEID}"
fi

#get transport zones ids
HOSTTZID=$(get_transport_zone_id "${AZNAME_LOWER}-host-vlan-tz")
echo "  HOST TZ ID: ${HOSTTZID}"
OVERLAYTZID=$(get_transport_zone_id "overlay-tz")
echo "  OVERLAY TZ ID: ${OVERLAYTZID}"

#GET IP POOL ID
IPPOOLID=$(get_ip_pool_path "${AZNAME_LOWER}-TEP-pool")
echo "  IP POOL ID : ${IPPOOLID}"

echo
echo "Checking Transport Nodes Profile"
HTNPROFILENAME="${AZNAME_LOWER}-cluster-transport-node-profile"

## need to add check that vcenter inventory completed in NSX Manager
echo "test if TNP ${HTNPROFILENAME} exists"
TEST=$(get_host_transport_node_profile_id "${HTNPROFILENAME}")
echo "${TEST}"
if  [[ "${TEST}" == *"error"* ]] || [[ "${TEST}" == "" ]] ;then
        echo "Creating Transport Nodes Profile : ${HTNPROFILENAME}"
        create_transport_node_profile "${HTNPROFILENAME}" "${VDSUUID}" "${HOSTTZID}" "${OVERLAYTZID}" "${IPPOOLID}" "${HOSTPROFILEID}" "${VDSUPLINKS[0]}" "${VDSUPLINKS[1]}"
fi


# ===== Configure NSX on ESX hosts =====
echo
echo Configuring NSX on ESX hosts
echo

CLUSTERCCID=$(get_compute_collection_external_id "${AZNAME_LOWER}")
echo "  Cluster CCID : ${CLUSTERCCID}" 

# check current state
echo "  get_host-transport-nodes"
echo
get_host-transport-nodes
TNC=$(check_transport_node_collections)
if [[ "${TEST}" != *"error"* ]]
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
        create_transport_node_collections "${CLUSTERCCID}" "${HTNPROFILEID}"
        sleep 30
        loop_wait_host_state
fi


# ===== create nsx segments for edge vms =====
# edge-uplink-trunk-1 - tz = host-vlan-tz - teaming policy : host-profile-uplink-1 - vlan : 0-4094
# edge-uplink-trunk-2 - tz = host-vlan-tz - teaming policy : host-profile-uplink-2 - vlan : 0-4094
echo "Processing segments"

echo
GETSEGMENT=$(get_segment "${AZNAME_LOWER}-edge-uplink-trunk-1")

if [[ "${GETSEGMENT}" == *"error"* ]]
then
        TZID=$(get_transport_zone_id "${AZNAME_LOWER}-host-vlan-tz")
        create_edge_segment "${AZNAME_LOWER}-edge-uplink-trunk-1" "$TZID" "${AZNAME_LOWER}-host-profile-uplink-1"
else
        echo "  ${AZNAME_LOWER}-edge-uplink-trunk-1 - present"
fi

echo
GETSEGMENT=$(get_segment "${AZNAME_LOWER}-edge-uplink-trunk-2")
if [[ "${GETSEGMENT}" == *"error"* ]]
then
        TZID=$(get_transport_zone_id "${AZNAME_LOWER}-host-vlan-tz")
        create_edge_segment "${AZNAME_LOWER}-edge-uplink-trunk-2" "$TZID" "${AZNAME_LOWER}-host-profile-uplink-2"
else
        echo "  ${AZNAME_LOWER}-edge-uplink-trunk-2 - present"
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
CLUSTERCCID=$(get_compute_collection_origin_id "${AZCPOD_NAME_LOWER}")
if  [[ "${CLUSTERCCID}" == *"error"* ]] || [[ "${CLUSTERCCID}" == "" ]] ;then
        echo "  problem getting Cluster ID : ${AZCPOD_NAME_LOWER}"
        exit  
else   
        echo " CLUSTERCCID : ${CLUSTERCCID}"
fi

COMPUTE_ID=$(get_compute_collection_local_id "${AZCPOD_NAME_LOWER}")
if  [[ "${COMPUTE_ID}" == *"error"* ]] || [[ "${COMPUTE_ID}" == "" ]] ;then
        echo "  problem getting Cluster ID : ${AZCPOD_NAME_LOWER}"
        exit  
else   
        echo " COMPUTE_ID : ${COMPUTE_ID}"
fi

# Datastore ID
# govc datastore.info -json=true vsanDatastore |jq -r .Datastores[].Self.Value
STORAGE_ID=$(govc datastore.info -json=true "${CPOD_NAME_LOWER}-vsanDatastore" |jq -r .Datastores[].Self.Value)

# Portgroup ID
# govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="vlan-0-mgmt") | .Network.Value'
# 
MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="'${CPOD_NAME_LOWER}'-mgmt") | .Network.Value')
if [ "${MANAGEMENT_NETWORK_ID}" == "" ]
then
        MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].Object.Summary | select (.Name =="VM Network") | .Network.Value')
fi
echo " MANAGEMENT_NETWORK_ID : ${MANAGEMENT_NETWORK_ID}"

OVLYTZID=$(get_transport_zone_uniqueid "overlay-tz")
VLANTZID=$(get_transport_zone_uniqueid "${AZNAME_LOWER}-edge-vlan-tz")

#OVLYTZID=$(get_transport_zone_path "overlay-tz")
#VLANTZID=$(get_transport_zone_path "edge-vlan-tz")

#UPLINKPROFILEID=$(get_uplink_profile_uniqueid "edge-profile")
UPLINKPROFILEID=$(get_uplink_profile_path "${AZNAME_LOWER}-edge-profile")

#get_ip_pool_all
IPPOOLID=$(get_ip_pool_id "${AZNAME_LOWER}-TEP-pool")

# deploy edge code here
echo "edge-${AZNAME_LOWER}"
EDGEID=$(get_transport_node "edge-${AZNAME_LOWER}")
if  [[ "${EDGEID}" == *"error"* ]] || [[ "${EDGEID}" == "" ]] 
then
        EDGE_IP="${SUBNET}.54"
        FQDN="edge-${AZNAME_LOWER}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
        create_edge_node "edge-${AZNAME_LOWER}" "${UPLINKPROFILEID}" "${IPPOOLID}" "${OVLYTZID}" "${VLANTZID}" "${CLUSTERCCID}" "${COMPUTE_ID}" "${STORAGE_ID}" "${MANAGEMENT_NETWORK_ID}" "${EDGE_IP}" "${FQDN}"
else
        echo "  edge-${AZNAME_LOWER} is present"
fi

# check edge node status - Not Available -> ready  in "configuration state" - "Registration Pending" - Success

loop_get_edge_nodes_state

# ===== Script finished =====
echo "${AZNAME_LOWER} Hosts and Edge Configuration done"
