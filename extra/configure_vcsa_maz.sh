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


POD_FQDN="${CPOD_MGMT_LOWER}.${ROOT_DOMAIN}"

export GOVC_USERNAME="administrator@${POD_FQDN}"
export GOVC_PASSWORD="${PASSWORDMGMT}"
export GOVC_URL="https://vcsa.${POD_FQDN}"
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
govc cluster.create -dc=${DATACENTER} $CPOD_AZ1_LOWER
govc cluster.create -dc=${DATACENTER} $CPOD_AZ2_LOWER
govc cluster.create -dc=${DATACENTER} $CPOD_AZ3_LOWER

#create dvs switches
govc dvs.create  -dc=${DATACENTER}  -mtu 9000 -num-uplinks=2 $CPOD_AZ1_LOWER
govc dvs.create  -dc=${DATACENTER}  -mtu 9000 -num-uplinks=2 $CPOD_AZ2_LOWER
govc dvs.create  -dc=${DATACENTER}  -mtu 9000 -num-uplinks=2 $CPOD_AZ3_LOWER

#Add hosts to clusters
#AZ1
AZ1HOSTS=$(list_cpod_esx_hosts $CPOD_AZ1_LOWER)
for ESXHOST in ${AZ1HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster $CPOD_AZ1_LOWER -hostname $ESXHOST -username root -password ${PASSWORDAZ1} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs=$CPOD_AZ1_LOWER -pnic vmnic1 $ESXHOST
done
govc -dc=${DATACENTER} object.rename /MAZ-DC/datastore/nfsDatastore nfsDatastore-AZ1

#AZ2
AZ2HOSTS=$(list_cpod_esx_hosts $CPOD_AZ2_LOWER)
for ESXHOST in ${AZ2HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster $CPOD_AZ2_LOWER -hostname $ESXHOST -username root -password ${PASSWORDAZ2} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs=$CPOD_AZ2_LOWER -pnic vmnic1 $ESXHOST
done
govc -dc=${DATACENTER} object.rename /MAZ-DC/datastore/nfsDatastore nfsDatastore-AZ2

#AZ3
AZ3HOSTS=$(list_cpod_esx_hosts $CPOD_AZ3_LOWER)
for ESXHOST in ${AZ3HOSTS}; do
	govc cluster.add -dc=${DATACENTER} -cluster $CPOD_AZ3_LOWER -hostname $ESXHOST -username root -password ${PASSWORDAZ3} -noverify
	govc dvs.add -dc=${DATACENTER}  -dvs=$CPOD_AZ3_LOWER -pnic vmnic1 $ESXHOST
done
govc -dc=${DATACENTER} object.rename /MAZ-DC/datastore/nfsDatastore nfsDatastore-AZ3

