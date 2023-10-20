#!/bin/bash
#edewitte@vmware.com

# sourcing params and functions

source ./env 
source ./extra/functions.sh


[ "${1}" == "" ] && echo "usage: ${0} <Management cPod Name> <AZ1 cPdo Name> <AZ2 cPdo Name> <AZ3 cPod Name>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi
echo
echo "==========================================="
echo "=== Configuring VCSA for Multi-AZ setup ==="
echo "==========================================="
echo
####################
# Local function

create_vlans_pg_dvs() { 
	# ${1} = AZx_VLANID - example $AZ1_VLANID
	# ${2} = DVS name - example "${CPOD_AZ1_LOWER}" 

	VLANID=${1}
	DVSNAME=${2}
	CPODNAME=${3}

	if [ ${VLANID} -gt 40 ]; then
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}1 "$CPODNAME-vmotion"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}2 "$CPODNAME-vsan"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}3 "$CPODNAME-TEPS"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}4 "$CPODNAME-uplinks"
	else
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}01 "$CPODNAME-vmotion"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}02 "$CPODNAME-vsan"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}03 "$CPODNAME-TEPS"
		govc dvs.portgroup.add -dc=${DATACENTER} -dvs $DVSNAME -type ephemeral -vlan=${VLANID}04 "$CPODNAME-uplinks"
	fi
}

create_vmkernel_interfaces() {
	# ${1} = cluster
	# ${2} = dvs
	# ${3} = portgroup
	# ${4} = vmotion pg

	CLUSTER="${1}"
	VLAN="${2}"
	VDS="${3}"
	PORTGROUP="${4}"
	VMOTIONPORTGROUP="${5}"
	VSANPORTGROUP="${6}"

	echo
	echo "========================================================"
	echo "Creating vmkernels with powercli"
	echo "========================================================"

	PS_SCRIPT=configure_vcsa_maz-nsxt.ps1

	SCRIPT_DIR=/tmp/scripts
	SCRIPT=/tmp/scripts/$$.ps1

	mkdir -p ${SCRIPT_DIR}
	cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

	CPOD_VCSA=vcsa.${CPOD_FQDN}
	CPOD_ADMIN="administrator@${CPOD_FQDN}"
	CPOD_PWD="${PASSWORDMGMT}"

	sed -i -e "s/###VCENTER###/${CPOD_VCSA}/" ${SCRIPT}
	sed -i -e "s/###VCENTER_ADMIN###/${CPOD_ADMIN}/" ${SCRIPT}
	sed -i -e "s/###VCENTER_PASSWD###/${CPOD_PWD}/" ${SCRIPT}
	sed -i -e "s/###VLAN###/${VLAN}/" ${SCRIPT}
	sed -i -e "s/###CLUSTER###/${CLUSTER}/" ${SCRIPT}
	sed -i -e "s/###VDS###/${VDS}/" ${SCRIPT}
	sed -i -e "s/###MGMTPORTGROUP###/${PORTGROUP}/" ${SCRIPT}
	sed -i -e "s/###VMOTIONPORTGROUP###/${VMOTIONPORTGROUP}/" ${SCRIPT}
	sed -i -e "s/###VSANPORTGROUP###/${VSANPORTGROUP}/" ${SCRIPT}

	docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}
	#rm -fr ${SCRIPT}

}

enable_vsan_cluster() {
	# ${1} = cluster

	CLUSTER="${1}"

	echo
	echo "========================================================"
	echo "Creating vmkernels with powercli"
	echo "========================================================"

	PS_SCRIPT=configure_vcsa_maz_enable_drs_vsan.ps1

	SCRIPT_DIR=/tmp/scripts
	SCRIPT=/tmp/scripts/$$.ps1

	mkdir -p ${SCRIPT_DIR}
	cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

	CPOD_VCSA=vcsa.${CPOD_FQDN}
	CPOD_ADMIN="administrator@${CPOD_FQDN}"
	CPOD_PWD="${PASSWORDMGMT}"

	sed -i -e "s/###VCENTER###/${CPOD_VCSA}/" ${SCRIPT}
	sed -i -e "s/###VCENTER_ADMIN###/${CPOD_ADMIN}/" ${SCRIPT}
	sed -i -e "s/###VCENTER_PASSWD###/${CPOD_PWD}/" ${SCRIPT}
	sed -i -e "s/###CLUSTER###/${CLUSTER}/" ${SCRIPT}

	docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}
	#rm -fr ${SCRIPT}

}



###################
#Check CPODnames are correct and exist

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


CPOD_MGMT="cpod-$1"
CPOD_MGMT_LOWER=$( echo ${CPOD_MGMT} | tr '[:upper:]' '[:lower:]' )

CPOD_AZ1="cpod-$2"
CPOD_AZ1_LOWER=$( echo ${CPOD_AZ1} | tr '[:upper:]' '[:lower:]' )

CPOD_AZ2="cpod-$3"
CPOD_AZ2_LOWER=$( echo ${CPOD_AZ2} | tr '[:upper:]' '[:lower:]' )

CPOD_AZ3="cpod-$4"
CPOD_AZ3_LOWER=$( echo ${CPOD_AZ3} | tr '[:upper:]' '[:lower:]' )

PASSWORDMGMT=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )
PASSWORDAZ1=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${2} )
PASSWORDAZ2=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${3} )
PASSWORDAZ3=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${4} )

CPOD_FQDN="${CPOD_MGMT_LOWER}.${ROOT_DOMAIN}"

AZ1_VLANID=$( cat /etc/hosts | grep ${CPOD_AZ1_LOWER} | cut -f1 | cut -d"." -f4 )
AZ2_VLANID=$( cat /etc/hosts | grep ${CPOD_AZ2_LOWER} | cut -f1 | cut -d"." -f4 )
AZ3_VLANID=$( cat /etc/hosts | grep ${CPOD_AZ3_LOWER} | cut -f1 | cut -d"." -f4 )

export GOVC_USERNAME="administrator@${CPOD_FQDN}"
export GOVC_PASSWORD="${PASSWORDMGMT}"
export GOVC_URL="https://vcsa.${CPOD_FQDN}"
export GOVC_INSECURE=1

echo
echo "========================================"
echo "=== Creating Datacenter and Clusters ==="
echo "========================================"
echo

DATACENTER="MAZ-DC"
#Create MAZ Datacenter
govc datacenter.create ${DATACENTER};

#Create Clusters
govc cluster.create -dc=${DATACENTER} "${CPOD_AZ1_LOWER}"
govc cluster.create -dc=${DATACENTER} "${CPOD_AZ2_LOWER}"
govc cluster.create -dc=${DATACENTER} "${CPOD_AZ3_LOWER}"

DVSAZ1="dvs-${CPOD_AZ1_LOWER}"
DVSAZ2="dvs-${CPOD_AZ2_LOWER}"
DVSAZ3="dvs-${CPOD_AZ3_LOWER}"
DVSMAZ="dvs-maz"

#create dvs switches
govc dvs.create  -dc=${DATACENTER}  -mtu 9000 -num-uplinks=2 "${DVSMAZ}"

govc dvs.portgroup.add -dc=${DATACENTER} -dvs "${DVSMAZ}" -type ephemeral "${CPOD_AZ1_LOWER}-mgmt"
create_vlans_pg_dvs $AZ1_VLANID "${DVSMAZ}" "${CPOD_AZ1_LOWER}"

govc dvs.portgroup.add -dc=${DATACENTER} -dvs "${DVSMAZ}" -type ephemeral "${CPOD_AZ2_LOWER}-mgmt"
create_vlans_pg_dvs $AZ2_VLANID "${DVSMAZ}"  "${CPOD_AZ2_LOWER}"

govc dvs.portgroup.add -dc=${DATACENTER} -dvs "${DVSMAZ}" -type ephemeral  "${CPOD_AZ3_LOWER}-mgmt"
create_vlans_pg_dvs $AZ3_VLANID "${DVSMAZ}"  "${CPOD_AZ3_LOWER}"

#Add hosts to clusters ans set vmkernel ports
#AZ1
AZ1HOSTS=$(list_cpod_esx_hosts "${CPOD_AZ1_LOWER}")
for ESXHOST in ${AZ1HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster "${CPOD_AZ1_LOWER}" -hostname $ESXHOST -username root -password ${PASSWORDAZ1} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs="${DVSMAZ}" -pnic vmnic1 $ESXHOST
done
govc object.rename -dc=${DATACENTER} /MAZ-DC/datastore/nfsDatastore "${CPOD_AZ1}-nfsDatastore"
create_vmkernel_interfaces "${CPOD_AZ1_LOWER}" "${AZ1_VLANID}" "${DVSMAZ}" "${CPOD_AZ1_LOWER}-mgmt" "${CPOD_AZ1_LOWER}-vmotion" "${CPOD_AZ1_LOWER}-vsan" 

#AZ2
AZ2HOSTS=$(list_cpod_esx_hosts "${CPOD_AZ2_LOWER}")
for ESXHOST in ${AZ2HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster "${CPOD_AZ2_LOWER}" -hostname $ESXHOST -username root -password ${PASSWORDAZ2} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs="${DVSMAZ}" -pnic vmnic1 $ESXHOST
done
govc object.rename -dc=${DATACENTER} "/MAZ-DC/datastore/nfsDatastore" "${CPOD_AZ2}-nfsDatastore"
create_vmkernel_interfaces "${CPOD_AZ2_LOWER}" "${AZ2_VLANID}" "${DVSMAZ}" "${CPOD_AZ2_LOWER}-mgmt" "${CPOD_AZ2_LOWER}-vmotion" "${CPOD_AZ2_LOWER}-vsan" 

#AZ3
AZ3HOSTS=$(list_cpod_esx_hosts "${CPOD_AZ3_LOWER}")
for ESXHOST in ${AZ3HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster "${CPOD_AZ3_LOWER}" -hostname $ESXHOST -username root -password ${PASSWORDAZ3} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs="${DVSMAZ}" -pnic vmnic1 $ESXHOST
done
govc object.rename -dc=${DATACENTER} "/MAZ-DC/datastore/nfsDatastore" "${CPOD_AZ3}-nfsDatastore"
create_vmkernel_interfaces "${CPOD_AZ3_LOWER}" "${AZ3_VLANID}" "${DVSMAZ}" "${CPOD_AZ3_LOWER}-mgmt" "${CPOD_AZ3_LOWER}-vmotion" "${CPOD_AZ3_LOWER}-vsan" 

# Enable VSAN
#AZ1
enable_vsan_cluster "${CPOD_AZ1_LOWER}"
govc object.rename -dc=${DATACENTER} "/MAZ-DC/datastore/vsanDatastore" "${CPOD_AZ1}-vsanDatastore"

#AZ2
enable_vsan_cluster "${CPOD_AZ2_LOWER}"
govc object.rename -dc=${DATACENTER} "/MAZ-DC/datastore/vsanDatastore" "${CPOD_AZ2}-vsanDatastore"

#AZ3
enable_vsan_cluster "${CPOD_AZ3_LOWER}"
govc object.rename -dc=${DATACENTER} "/MAZ-DC/datastore/vsanDatastore" "${CPOD_AZ3}-vsanDatastore"

echo
echo "================================================="
echo "=== VCSA and clusters Configuration completed ==="
echo "================================================="
echo
