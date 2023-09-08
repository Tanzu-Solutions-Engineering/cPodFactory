#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

if [ -z "$LOGGING" ]
then
    echo "enabling logging"
    export LOGGING="TRUE"
    /usr/bin/script /tmp/scripts/test-$$-log.txt /bin/bash -c "$0 $*"
    exit 0
fi

START=$( date +%s ) 

[ "$1" == "" -o "$2" == ""  -o "$3" == ""  ] && echo "usage: $0 <name_of_cpod>  <#esx> <name_of_owner>"  && echo "usage example: $0 LAB01 4 vedw" && exit 1

if [ "$TERM" = "screen" ] && [ -n "$TMUX" ]; then
  echo "You are running in a tmux session. That is very wise of you !  :)"
else
  echo "You are not running in a tmux session. Maybe you want to run this in a tmux session?"
  echo "stopping script because you're not in a TMUX session."
  exit
fi

# sourcing params and functions

source ./env 
source ./govc_env
source ./extra/functions.sh

# let's get started

echo
echo "====================================="
echo "=== Select CPOD version to deploy ==="
echo "====================================="
echo


options=$(ls vsphere*.sh)
options=${options}" Quit"

select VERSION in ${options}; do 
    if [ "${VERSION}" = "Quit" ]; then 
      exit
    fi
    echo "you selected version : ${VERSION}"
    source ./${VERSION}
    break
done

echo
echo "======================"
echo "=== checking files ==="
echo "======================"
echo

test_params_file ${VERSION}

echo
echo "======================"
echo "=== creating cpods ==="
echo "======================"
echo

MGMTCPOD=$1-mgmt
AZ1CPOD=$1-az1
AZ2CPOD=$1-az2
AZ3CPOD=$1-az3

cpodctl create ${MGMTCPOD} 0 $3
cpodctl create ${AZ1CPOD} 4 $3
cpodctl create ${AZ2CPOD} 4 $3
cpodctl create ${AZ3CPOD} 4 $3

./extra/deploy_vcsa_only.sh ${MGMTCPOD} $3
./extra/configure_vcsa_maz-nsxt.sh ${MGMTCPOD} ${AZ1CPOD} ${AZ2CPOD} ${AZ3CPOD}

./extra/deploy_nsxt_mgr_v4.sh ${MGMTCPOD} $3
./extra/configure_nsxt_atside_maz_init.sh ${MGMTCPOD} $3
./extra/info_nsxt_cpod.sh ${MGMTCPOD} $3
./extra/configure_nsxt_atside_maz_az-config.sh ${MGMTCPOD} ${AZ1CPOD}
./extra/configure_nsxt_atside_maz_az-config.sh ${MGMTCPOD} ${AZ2CPOD}
./extra/configure_nsxt_atside_maz_az-config.sh ${MGMTCPOD} ${AZ3CPOD}
#./extra/configure_nsxt_atside_maz_az-tier0.sh ${MGMTCPOD} ${AZ1CPOD} ${AZ2CPOD} ${AZ3CPOD} 

END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "============================="
echo "===  creation is finished ==="
echo "=== In ${TIME} Seconds ==="
echo "============================="

echo
./info_cpod.sh ${MGMTCPOD}

export LOGGING=""