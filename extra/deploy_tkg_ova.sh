#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0}  <CPOD name> " && exit 1


if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### Local vars ###

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################
# get cpod govc params

NAME="$( echo ${1} | tr '[:lower:]' '[:upper:]' )"
POD_NAME="cPod-${1}"
POD_NAME_LOWER="$( echo ${POD_NAME} | tr '[:upper:]' '[:lower:]' )"
POD_FQDN="${POD_NAME_LOWER}.${ROOT_DOMAIN}"

if [ -z ${PSC_DOMAIN} ]; then
	export GOVC_USERNAME="administrator@${POD_FQDN}"
else
	export GOVC_USERNAME="administrator@${PSC_DOMAIN}"
fi

if [ -z ${PSC_DOMAIN} ]; then
	export GOVC_PASSWORD="$( ./extra/passwd_for_cpod.sh ${1} )"
else
	export GOVC_PASSWORD="${PSC_PASSWORD}"
	VCENTER_CPOD_PASSWD=${PSC_PASSWORD}
fi

export GOVC_URL="https://${GOVC_USERNAME}:${GOVC_PASSWORD}@vcsa.${POD_FQDN}"
export GOVC_DATACENTER=""

#get datacenter
DATACENTERSLIST=$(govc find / -type d  | cut -d "/" -f2 | sort)
if [ $? -eq 0 ]
then
    echo
    echo "Select desired datacenter or CTRL-C to quit"
    echo
    select DATACENTER in $DATACENTERSLIST; do 
        echo "Datacenter selected :  $DATACENTER"
        GOVC_DC=$DATACENTER
        break
    done
else
    echo "problem getting datacenters list via govc" >&2
    exit 1
fi

#get cluster
CLUSTERSLIST=$(govc find -dc="${GOVC_DC}" -type ClusterComputeResource | rev | cut -d "/" -f1 | rev )
if [ $? -eq 0 ]
then
    echo
    echo "Select desired cluster or CTRL-C to quit"
    echo
    select CLUSTER in $CLUSTERSLIST; do 
        echo "Cluster selected :  $CLUSTER"
        GOVC_CLUSTER=$CLUSTER
        break
    done
else
    echo "problem getting clusters list via govc" >&2
    exit 1
fi

#get datastore
DSLIST=$(govc find -dc="${GOVC_DC}" -type Datastore | rev | cut -d "/" -f1 | rev )
if [ $? -eq 0 ]
then
    echo
    echo "Select desired datastore or CTRL-C to quit"
    echo
    select DATASTORE in $DSLIST; do 
        echo "Datastore selected :  $DATASTORE"
        break
    done
else
    echo "problem getting datastores list via govc" >&2
    exit 1
fi

#get vm folder
SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
FOLDERSLIST=$(govc find -dc="${GOVC_DC}" -type Folder  |grep "./vm" | sed 's/\.\/vm\///g' | grep -v "./vm" )
if [ $? -eq 0 ]
then
    echo
    echo "Select desired folder or CTRL-C to quit"
    echo
    select FOLDER in ${FOLDERSLIST}; do 
        echo "Folder selected :  $FOLDER"
        break
    done
else
    echo "problem getting folders list via govc" >&2
    exit 1
fi
IFS=$SAVEIFS

#get portgroup
PGLIST=$(govc find -dc="${GOVC_DC}" -type DistributedVirtualPortgroup | rev | cut -d "/" -f1 | rev
)
if [ $? -eq 0 ]
then
    echo
    echo "Select desired cluster or CTRL-C to quit"
    echo
    select PORTGROUP in $PGLIST; do 
        echo "PORTGROUP selected :  $PORTGROUP"
        break
    done
else
    echo "problem getting clusters list via govc" >&2
    exit 1
fi

#get TKG OVA to import
OVASLIST=$(ls /data/BITS/*tkg* | sort)
if [ $? -eq 0 ]
then
    echo
    echo "Select desired OVA or CTRL-C to quit"
    echo
    select OVA in $OVASLIST; do 
        echo "OVA selected :  $OVA"
        break
    done
else
    echo "problem getting ova list" >&2
    exit 1
fi

echo "enter name for vm"
read VMNAME
VMNAME=$( echo ${VMNAME} | tr '[:upper:]' '[:lower:]' )

govc import.spec "${OVA}"  | jq . > /tmp/photon.jq

cat /tmp/photon.jq | jq '.NetworkMapping[].Network="'${PORTGROUP}'"' > /tmp/photon-2.jq

HOST=$(govc find -dc="${GOVC_DC}" -type h -json=true /${GOVC_DC}/host/$CLUSTER | jq -r '.[0]') #govc jq checked

echo "Importing $OVA as $VMNAME"
govc import.ova -options=/tmp/photon-2.jq  -host=${HOST} -pool=/${GOVC_DC}/host/$CLUSTER/Resources -dc=/${GOVC_DC} -folder="/${GOVC_DC}/vm/${FOLDER}" -ds=/${GOVC_DC}/datastore/${DATASTORE} -name=${VMNAME}  ${OVA}

govc vm.markastemplate -dc=/${GOVC_DC} ${VMNAME}

