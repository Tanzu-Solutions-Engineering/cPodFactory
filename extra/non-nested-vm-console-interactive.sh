#!/bin/bash -e
#edewitte@vmware.com

# script to issue login keystrokes at console

# see cpdofactory : install/cpodrouter/cpodrouter-photon5-steps.md

# deploy OVA

source ./env


#[ "${1}" == "" ] && echo "usage: ${0}  <CPOD name>" && echo "example:  ${0} services" && exit 1

###################
source govc_env
###################

# CPOD_NAME="cpod-$1"
# NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
# CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
# LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )

# CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
# VAPP="cPod-${NAME_HIGHER}"
# NAME="${VAPP}-${HOSTNAME}"

# PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

#welcome message
echo
echo "This script will send username and password via console keystrokes."
echo "Please make sure your VM console is at the screen for username/password authentication"

# Select VM
echo 
echo "Select vm to console login"
echo
VMFILTER=${1}

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")
VMS=$(govc find / -type m | grep -v "vCLS" |grep -i "${VMFILTER}" |sort)
select VM in ${VMS}; do 
    if [ "${VM}" = "Quit" ]; then 
      exit
    fi
    echo "you selected VM : ${VM}"
    break
done
IFS=$SAVEIFS


echo
echo "Proceeding to console login"

if [ "$VM" == "" ]
then
  echo "VM name is empty" 
  exit
fi

echo 
echo "interactive console keystrokes started. press ctrl-c to stop"
echo

while true
do
  echo
  read -r COMMAND
  govc vm.keystrokes -vm $VM -s "${COMMAND}"
  govc vm.keystrokes -vm $VM -c KEY_ENTER

done