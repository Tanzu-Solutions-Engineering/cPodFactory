#!/bin/bash
#edewitte@vmware.com

# $1 : Name of cpod to modify
# $2 : Name of owner

# This solution deploys a vSphere cluster and configure a vDS with networks for vSAN and VMotion and then enables vSAN & DRS

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
echo "====================================="
echo "=== creating cpod / vsan / NLB  ==="
echo "====================================="
echo

cpodctl create $1 $2 $3
cpodctl vcsa $1 $3
./extra/create_vds_vsan.sh $1 $3
./extra/enable_vsanOSA.sh $1 $3


#get data
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

END=$( date +%s )
TIME=$( expr ${END} - ${START} )

echo
echo "============================="
echo "===  creation is finished ==="
echo "=== In ${TIME} Seconds ==="
echo "============================="

echo "=== connect to cpod vcsa ==="
echo "=== url: https://vcsa.${NAME_LOWER}.${ROOT_DOMAIN}/ui"
echo "== user : administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo "=== pwd : ${PASSWORD}"
echo "============================="

export LOGGING=""
