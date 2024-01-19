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
source ./extra/functions_nsxt.sh

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

echo
echo "========================="
echo "Configuring NSX-T manager"
echo "========================="
echo

NSXFQDN=${HOSTNAME}.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}
echo ${NSXFQDN}

echo "  waiting for nsx mgr to answer ping"
echo 

STATUS=$( ping -c 1 ${NSXFQDN} 2>&1 > /dev/null ; echo $? )
printf "\t ping nsx ."
while [[ ${STATUS} != 0  ]]
do
        sleep 10
        STATUS=$( ping -c 1 ${NSXFQDN} 2>&1 > /dev/null ; echo $? )
        printf '.' >/dev/tty
done
echo
echo
loop_wait_nsx_manager_status

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
                                echo "  Version is at lease 4.1"
                        else
                                echo "  Version is below 4.1. Script uses newer API (>3.2 or >4.1). stopping here."
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

nsx_accept_eula

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
echo
POOL=$(check_ip_pool "TEP-pool")
if [[ "${POOL}" == *"error"* ]] || [[ "${POOL}" == "" ]] 
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
# govc ls -json=true network |jq -r '.elements[] | select ( .Object.summary.productInfo.name == "DVS") |  .Object.summary.uuid' #govc jq checked

VDSUUID=$(govc ls -json=true network |jq -r '.elements[] | select ( .Object.summary.productInfo.name == "DVS") |  .Object.summary.uuid') #govc jq checked
echo "  VDS UUID : ${VDSUUID}"
if [ "${VDSUUID}" == "" ]
then
        echo "  problem getting VDS UUID"
        exit
fi

echo "Getting VDS uplinks"
readarray -t VDSUPLINKS < <(govc ls -json=true network |jq -r '.elements[] | select ( .Object.summary.productInfo.name == "DVS") |  .Object.config.uplinkPortPolicy.uplinkPortName[]') #govc jq checked
echo "  VDS UPLINKS : " 
echo "${VDSUPLINKS[@]}"
if [ "${VDSUPLINKS}" == "" ]
then
        echo "  problem getting VDS uplinks"
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
echo "test if TNP ${HTNPROFILENAME} exists"
TEST=$(get_host_transport_node_profile_id "${HTNPROFILENAME}")
echo "${TEST}"

if  [[ "${TEST}" == *"error"* ]] || [[ "${TEST}" == "" ]] ;then
        echo "Creating Transport Nodes Profile : ${HTNPROFILENAME}"
        create_transport_node_profile "${HTNPROFILENAME}" "${VDSUUID}" "${HOSTTZID}" "${OVERLAYTZID}" "${IPPOOLID}" "${HOSTPROFILEID}" "${VDSUPLINKS[0]}" "${VDSUPLINKS[1]}"
        HTNPROFILEID=$(get_host_transport_node_profile_id "${HTNPROFILENAME}")
else
        HTNPROFILEID="${TEST}"
fi
echo "HTN = ${HTNPROFILENAME} = ID : ${HTNPROFILEID}"

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
echo
echo "Check Transport Node Collections"
TNC=$(check_transport_node_collections)

if [[ "${TNC}" != *"error"* ]] || [[ "${TNC}" == "" ]]
then
        TNCID=$(echo ${TNC} |jq -r '.results[] | select (.compute_collection_id == "'${CLUSTERCCID}'") | .id ' )
        echo "TNCID : ${TNCID}"
        if [[ "${TNCID}" == *"error"* ]] || [[ "${TNCID}" == "" ]]
        then
                echo "  Configuring NSX on hosts"
                echo
                create_transport_node_collections "${CLUSTERCCID}" "${HTNPROFILEID}"
                sleep 30
                loop_wait_host_state
        else
                echo
                echo "  TNCID: $TNCID"
                echo "  Cluster Collection State :  $(get_transport_node_collections_state ${TNCID})"
                echo
                loop_wait_host_state
        fi
else
        echo "  Issue get_host-transport-nodes"
        exit
fi

# ===== create nsx segments for edge vms =====
# edge-uplink-trunk-1 - tz = host-vlan-tz - teaming policy : host-profile-uplink-1 - vlan : 0-4094
# edge-uplink-trunk-2 - tz = host-vlan-tz - teaming policy : host-profile-uplink-2 - vlan : 0-4094
echo "Processing segments"
echo

GETSEGMENT=$(get_segment "edge-uplink-trunk-1")
if [[ "${GETSEGMENT}" == *"error"* ]] || [[ "${GETSEGMENT}" == "" ]]
then
        TZID=$(get_transport_zone_id "host-vlan-tz")
        create_edge_segment "edge-uplink-trunk-1" "$TZID" "host-profile-uplink-1"
else
        echo "  edge-uplink-trunk-1 - present"
fi

echo
GETSEGMENT=$(get_segment "edge-uplink-trunk-2")
if [[ "${GETSEGMENT}" == *"error"* ]] || [[ "${GETSEGMENT}" == "" ]]
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
if  [[ "${CLUSTERCCID}" == *"error"* ]] || [[ "${CLUSTERCCID}" == "" ]] ;then
        echo "  problem getting Cluster ID : Cluster"
        exit  
else   
        echo " CLUSTERCCID : ${CLUSTERCCID}"
fi

COMPUTE_ID=$(govc ls -json=true host |jq -r '.elements[].Object.Self.value')  #govc jq checked
#COMPUTE_ID=$(get_compute_manager_id "${MGRNAME}")

# Datastore ID
STORAGE_ID=$(govc datastore.info -json=true vsanDatastore |jq -r .datastores[].Self.value)  #govc jq checked
echo " STORAGE_ID : ${STORAGE_ID}"

# Portgroup ID
# 
MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].object.summary | select (.name =="vlan-0-mgmt") | .network.value')  #govc jq checked
if [ "${MANAGEMENT_NETWORK_ID}" == "" ]
then
        MANAGEMENT_NETWORK_ID=$(govc ls -json=true network |jq -r '.elements[].Object.summary | select (.name =="VM Network") | .network.value') #govc jq checked
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
if  [[ "${EDGEID}" == *"error"* ]] || [[ "${EDGEID}" == "" ]] 
then
        EDGE_IP="${SUBNET}.54"
        FQDN="edge-1.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
        create_edge_node "edge-1" "${UPLINKPROFILEID}" "${IPPOOLID}" "${OVLYTZID}" "${VLANTZID}" "${CLUSTERCCID}" "${COMPUTE_ID}" "${STORAGE_ID}" "${MANAGEMENT_NETWORK_ID}" "${EDGE_IP}" "${FQDN}" "${CPODROUTERIP}" "edge-uplink-trunk"
else
        echo "  edge-1 is present"
fi

echo "edge-2"

EDGEID=$(get_transport_node "edge-2")
if  [[ "${EDGEID}" == *"error"* ]] || [[ "${EDGEID}" == "" ]] 
then
        EDGE_IP="${SUBNET}.55"
        FQDN="edge-2.${CPOD_NAME_LOWER}.${ROOT_DOMAIN}"
        create_edge_node "edge-2" "${UPLINKPROFILEID}" "${IPPOOLID}" "${OVLYTZID}" "${VLANTZID}" "${CLUSTERCCID}" "${COMPUTE_ID}" "${STORAGE_ID}" "${MANAGEMENT_NETWORK_ID}" "${EDGE_IP}" "${FQDN}"  "${CPODROUTERIP}" "edge-uplink-trunk"
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

TESTLOCALESERVICE=$(get_tier-0s_locale_services)

if [[ "${TESTLOCALESERVICE}" == *"error"* ]] || [ "${TESTLOCALESERVICE}" == "" ]
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

if  [[ "${INTERFACES}" == *"error"* ]] || [ "${INTERFACES}" == "" ]
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

# ===== Script finished =====
echo "Configuration done"
