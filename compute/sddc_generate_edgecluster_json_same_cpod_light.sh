#!/bin/bash
#edewitte@vmware.com

# $1 : cPod Name
# add : "server=/5.23.172.in-addr.arpa/172.23.5.1" in dnsmasq.conf @ wdm in order to add cPod as WD
# minimal deployment with : "excludedComponents": ["NSX-V", "AVN", "EBGP"] in json

. ./env

[ "$1" == "" ] || [ "$2" == "" ] && echo "usage: $0 <name_of_vcf_cpod> wldname "  && echo "usage example: $0 vcf45 wld01" && exit 1

source ./extra/functions.sh

source ./extra/functions_sddc_mgr.sh

EDGECLUSTER_JSON_TEMPLATE=./compute/sddc_edgecluster.json
#Management Domain CPOD
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

VLAN=$( grep -m 1 "${NAME_LOWER}\s" /etc/hosts | awk '{print $1}' | cut -d "." -f 4 )
VLAN_MGMT="${VLAN}"
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
VLAN_SHIFT=$( expr ${VLAN} + ${VLAN_SHIFT} )

case "${BACKEND_NETWORK}" in
    NSX-T)
        echo "NSX-T Backend"
        echo "VLAN_MGMT=0"
        VLAN_MGMT="0"
        ;;
    VLAN)
        VLANID=$( expr ${BACKEND_VLAN_OFFSET} + ${VLAN_MGMT} )
        VLAN_MGMT=${VLANID}
        echo "VLAN Backend"
        echo "VLAN_MGMT=${VLANID}"
        ;;
esac

WLDNAME="${2}"
#CLUSTERNAME="${3}"

SCRIPT_DIR=/tmp/scripts
mkdir -p ${SCRIPT_DIR} 

PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

# Check WLD exists in DNS entries

DNSCOUNT=$(ssh -o LogLevel=error -o StrictHostKeyChecking=no "${NAME_LOWER}" "cat /etc/hosts" |grep -c "${WLDNAME}")
if [[ $DNSCOUNT -gt 0 ]]
then
	echo "$DNSCOUNT dns entries found for ${WLDNAME} - proceeding"
else
	echo "no dns entries found for ${WLDNAME} "
        echo "bailing out"
	exit
fi

# Edge cluster params
# Edge TEP EDGETEPVLANID = 4
# Tier 0 uplink T0ULVLANID01 = 5
# Tier 0 uplink T0ULVLANID01 = 6
EDGETEPVLAN=4
T0ULVLAN01=5
T0ULVLAN02=6

if [[ ${VLAN} -gt 40 ]]; then
        EDGETEPVLANID="${VLAN}${EDGETEPVLAN}"
        T0ULVLANID01="${VLAN}${T0ULVLAN01}"
        T0ULVLANID02="${VLAN}${T0ULVLAN02}"
else
	EDGETEPVLANID="${VLAN}0${EDGETEPVLAN}"
        T0ULVLANID01="${VLAN}0${T0ULVLAN01}"
        T0ULVLANID02="${VLAN}0${T0ULVLAN02}"
fi

# edge nodes information
EN01IP=$(ssh -o LogLevel=error -o StrictHostKeyChecking=no "${NAME_LOWER}" "cat /etc/hosts" |grep -i "${WLDNAME}" | grep -i "en01" | awk '{print $1}')
if [[ "${EN01IP}" == "" ]]
then
	echo "${WLDNAME} dns entries on cpodrouter ${NAME_LOWER} not found for en01"
	echo "bailing out"
	exit
else
	echo "dns entries found for en01 : ${EN01IP}"
fi
EN01IP_IP=$(echo "${EN01IP}" | rev | cut -d "." -f1 |rev )

# edge nodes information
EN02IP=$(ssh -o LogLevel=error -o StrictHostKeyChecking=no "${NAME_LOWER}" "cat /etc/hosts" |grep -i "${WLDNAME}" | grep -i "en02" | awk '{print $1}')
if [[ "${EN01IP}" == "" ]]
then
	echo "${WLDNAME} dns entries on cpodrouter ${NAME_LOWER} not found for en02"
	echo "bailing out"
	exit
else
	echo "dns entries found for en02 : ${EN01IP}"
fi
EN02IP_IP=$(echo "${EN02IP}" | rev | cut -d "." -f1 |rev )

# Defining T0 interfaces

T0IP01="10.${VLAN}.${T0ULVLAN01}.${EN01IP_IP}"
T0IP02="10.${VLAN}.${T0ULVLAN01}.${EN02IP_IP}"
T0IP03="10.${VLAN}.${T0ULVLAN02}.${EN01IP_IP}"
T0IP04="10.${VLAN}.${T0ULVLAN02}.${EN02IP_IP}"
T0ULGW01="10.${VLAN}.${T0ULVLAN01}.1"
T0ULGW02="10.${VLAN}.${T0ULVLAN02}.1"

# configure cpodrouter bgp:
#
echo
echo checking bgp on cpodrouter
echo

ASNCPOD=$(get_cpod_asn ${NAME_LOWER})
ASNNSXT=$((ASNCPOD + 1000))
CPODBGPTABLE=$(get_cpodrouter_bgp_neighbors_table ${NAME_LOWER})
#test if already configured
IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP01})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP01} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP01}" "${ASNNSXT}" "${NAME_LOWER}"
else
        echo "  ${T0IP01} already defined as bgp neighbor"
fi

IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP02})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP02} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP02}" "${ASNNSXT}" "${NAME_LOWER}"
else
        echo "  ${T0IP02} already defined as bgp neighbor"
fi

IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP03})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP03} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP03}" "${ASNNSXT}" "${NAME_LOWER}"
else
        echo "  ${T0IP03} already defined as bgp neighbor"
fi

IPTEST=$(echo "${CPODBGPTABLE}" |grep ${T0IP04})
if [ "${IPTEST}" == "" ];
then
        echo "  adding ${T0IP04} bgp neighbor"
        add_cpodrouter_bgp_neighbor "${T0IP04}" "${ASNNSXT}" "${NAME_LOWER}"
else
        echo "  ${T0IP04} already defined as bgp neighbor"
fi

# Create Edgecluster JSON
SCRIPT=/tmp/scripts/edgecluster-${WLDNAME}-${NAME_LOWER}.json
mkdir -p ${SCRIPT_DIR}
cp ${EDGECLUSTER_JSON_TEMPLATE} ${SCRIPT}

EDGECLUSTERNAME="${WLDNAME}-edgecluster"
EDGE01FQDN="en01-${WLDNAME}.${NAME_LOWER}.${DOMAIN}"
EDGE02FQDN="en02-${WLDNAME}.${NAME_LOWER}.${DOMAIN}"
EN01IP="${EN01IP}/24"
EN02IP="${EN02IP}/24"
ENMGMTGW=$(echo "${EN01IP}" | awk -F "." '{print $1"."$2"."$3".1"}')
MGMTPORTGROUPNAME="${WLDNAME}-wld-cl01-vds-01-pg-mgmt-edge"
EDGE01TEPIP01="10.${VLAN}.${EDGETEPVLAN}.${EN01IP_IP}"
EN01IP_IP2=$((EN01IP_IP+10))
EDGE01TEPIP02="10.${VLAN}.${EDGETEPVLAN}.${EN01IP_IP2}"
EDGE02TEPIP01="10.${VLAN}.${EDGETEPVLAN}.${EN02IP_IP}"
EN02IP_IP2=$((EN01IP_IP+10))
EDGE02TEPIP02="10.${VLAN}.${EDGETEPVLAN}.${EN02IP_IP2}"
EDGETEPGW="10.${VLAN}.${EDGETEPVLAN}.1"
T0NAME="${WLDNAME}-t0"
T1NAME="${WLDNAME}-t1"

# Generate JSON for cloudbuilder
sed -i -e "s/###EDGECLUSTERNAME###/${EDGECLUSTERNAME}/g" ${SCRIPT}
sed -i -e "s/###PASSWORD###/${PASSWORD}/" ${SCRIPT}
sed -i -e "s/\"###ASNNUMBER###\"/${ASNNSXT}/" ${SCRIPT}
sed -i -e "s/###EDGE01FQDN###/${EDGE01FQDN}/" ${SCRIPT}
sed -i -e "s/###EDGE02FQDN###/${EDGE02FQDN}/" ${SCRIPT}
sed -i -e "s-###EDGE01MGMTIP###-${EN01IP}-" ${SCRIPT}
sed -i -e "s-###EDGE02MGMTIP###-${EN02IP}-" ${SCRIPT}
sed -i -e "s/###MGMTGW###/${ENMGMTGW}/" ${SCRIPT}
sed -i -e "s/###MGMTPORTGROUPNAME###/${MGMTPORTGROUPNAME}/" ${SCRIPT}
sed -i -e "s/###EDGE01TEPIP01###/${EDGE01TEPIP01}/" ${SCRIPT}
sed -i -e "s/###EDGE01TEPIP02###/${EDGE01TEPIP02}/" ${SCRIPT}
sed -i -e "s/###EDGE02TEPIP01###/${EDGE02TEPIP01}/" ${SCRIPT}
sed -i -e "s/###EDGE02TEPIP02###/${EDGE02TEPIP02}/" ${SCRIPT}
sed -i -e "s/###EDGETEPGW###/${EDGETEPGW}/" ${SCRIPT}
sed -i -e "s/\"###EDGETEPVLANID###\"/${EDGETEPVLANID}/" ${SCRIPT}
sed -i -e "s/\"###UPLINK01VLANID###\"/${T0ULVLANID01}/" ${SCRIPT}
sed -i -e "s/\"###UPLINK02VLANID###\"/${T0ULVLANID02}/" ${SCRIPT}
sed -i -e "s/###T0UPLINKIP01###/${T0IP01}/" ${SCRIPT}
sed -i -e "s/###T0UPLINKIP02###/${T0IP03}/" ${SCRIPT}
sed -i -e "s/###T0UPLINKIP03###/${T0IP02}/" ${SCRIPT}
sed -i -e "s/###T0UPLINKIP04###/${T0IP04}/" ${SCRIPT}
sed -i -e "s/###T0ULGW01###/${T0ULGW01}/" ${SCRIPT}
sed -i -e "s/###T0ULGW02###/${T0ULGW02}/" ${SCRIPT}
sed -i -e "s/\"###CPODROUTERASN###\"/${ASNCPOD}/" ${SCRIPT}
sed -i -e "s/###T0NAME###/${T0NAME}/" ${SCRIPT}
sed -i -e "s/###T1NAME###/${T1NAME}/" ${SCRIPT}

echo "JSON is generated: ${SCRIPT} and placed in directory: ${SCRIPT_DIR}."