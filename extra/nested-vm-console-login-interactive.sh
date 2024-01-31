#!/bin/bash -e
#edewitte@vmware.com

# script to issue login keystrokes at console

# see cpdofactory : install/cpodrouter/cpodrouter-photon5-steps.md

# deploy OVA

source ./env


[ "${1}" == "" ] && echo "usage: ${0}  <CPOD name>" && echo "example:  ${0} services" && exit 1

###################

set_govc_vcsa(){
    
    GOVC_USERNAME="administrator@${CPOD_NAME}.${ROOT_DOMAIN}"
    GOVC_PASSWORD="${PASSWORD}"
    GOVC_URL="${VCSA}.${CPOD_NAME}.${ROOT_DOMAIN}"
    GOVC_INSECURE=1
    #govc env
}

set_govc_factory(){
    source govc_env
}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )

CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
NAME="${VAPP}-${HOSTNAME}"

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

#welcome message
echo
echo "This script will send username and password via console keystrokes."
echo "Please make sure your VM console is at the screen for username/password authentication"


#Select vCenter
echo 
echo "Select vcenter instance"
echo
 
VCSAS=$(ssh ${CPOD_NAME} "cat /etc/hosts" |grep vcsa | awk '{print $2}')
VCSAS=${VCSAS}" Quit"

select VCSA in ${VCSAS}; do 
    if [ "${VCSA}" = "Quit" ]; then 
      exit
    fi
    echo "you selected VCSA : ${VCSA}"
    break
done
set_govc_vcsa
echo

# Select VM
echo 
echo "Select vm to console login"
echo

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

VMS=$(govc find / -type m | grep -v "vCLS" |sort)

select VM in ${VMS}; do 
    if [ "${VM}" = "Quit" ]; then 
      exit
    fi
    echo "you selected VM : ${VM}"
    break
done
IFS=$SAVEIFS

# Select user
echo 
echo "Select user to login with"
echo

USERS="root admin administrator@${CPOD_NAME}.${ROOT_DOMAIN} Quit"

select USER in ${USERS}; do 
    if [ "${USER}" = "Quit" ]; then 
      exit
    fi
    echo "you selected USER : ${USER}"
    break
done

# Select user
echo 
echo "Select user to login with"
echo

PWDS="cpod-password VMware1! Other Quit"

select PWD in ${PWDS}; do 
    if [ "${PWD}" = "Quit" ]; then 
      exit
    fi
    if [ "${PWD}" = "Other" ]; then 
      echo "Please enter password : "
      read -r PWD
    fi
    echo "you selected PWD : ${PWD}"
    if [ "${PWD}" = "cpod-password" ]; then 
        PWD="${PASSWORD}"
    fi
    break
done

echo
echo "Proceeding to console login"

if [ "$VM" != "" ]
then
    govc vm.keystrokes -vm $VM -s "${USER}"
    govc vm.keystrokes -vm $VM -c KEY_ENTER
    govc vm.keystrokes -vm $VM -s "${PASSWORD}"
    govc vm.keystrokes -vm $VM -c KEY_ENTER

    echo "console login done. please check via firefox"
else
    echo "VM name is empty" 

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