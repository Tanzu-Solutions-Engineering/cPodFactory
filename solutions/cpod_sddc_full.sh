#!/bin/bash
#goldyck@vmware.com

# $NAME : Name of cpod
# $2 : Name of owner

# if the cpod name equals ikea, then we  get the name of the cpod from the ikea script

if [ -z "$LOGGING" ]
then
    echo "enabling logging"
    export LOGGING="TRUE"
    /usr/bin/script /tmp/scripts/test-$$-log.txt /bin/bash -c "$0 $*"
    exit 0
fi

START=$( date +%s ) 

[ "$1" == "" -o "$2" == ""  -o "$3" == ""  ] && echo "usage: $0 <name_of_cpod> <version file> <name_of_owner>"  && echo "usage example: $0 ikea vcf45.sh vedw"  && exit 1

if [ "$TERM" = "screen" ] && [ -n "$TMUX" ]; then
  echo "You are running in a tmux session. That is very wise of you !  :)"
else
  echo "You are not running in a tmux session. Maybe you want to run this in a tmux session?"
  echo "stopping script because you're not in a TMUX session."
  exit
fi

#check if the cpod name equals ikea
if [ "$1" == "ikea" ]; then
  NAME=$("./extra/ikeaname.sh")
  echo "the name of your cpod will be: $NAME"
else
  NAME="${1}"
fi

#check if the cpod name exists by checking the host file
if grep -qF cpod-"$NAME" /etc/hosts; then
  echo "Error: $NAME already exists in /etc/hosts"
  exit 1
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

#find the file that contains the version file specified in $2
VERSION=$(find . -maxdepth 1 -type f -name "*$2*" | head -n 1)
echo "you selected version: ${VERSION}"
source ./${VERSION}

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

cpodctl create $NAME 4 $3
cpodctl cloudbuilder $NAME $3
./compute/sddc_generate_ems.sh $NAME
./compute/sddc_deploy_wld0_CB.sh $NAME

#get data
CPOD_NAME=$( echo ${NAME} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${HEADER}-${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} ) 

END=$( date +%s )
TIME=$( expr ${END} - ${START} )
TIME=$(date -d@$TIME -u +%Hh%Mm%Ss)

echo
echo "============================="
echo "===  creation is finished ==="
echo "=== In ${TIME} ==="
echo "============================="

echo "=== connect to cpod sddc ==="
echo "=== url: https://sddc.${NAME_LOWER}.${ROOT_DOMAIN}/ui"
echo "== user : administrator@${NAME_LOWER}.${ROOT_DOMAIN}"
echo "=== pwd : ${PASSWORD}"
echo "============================="

export LOGGING=""