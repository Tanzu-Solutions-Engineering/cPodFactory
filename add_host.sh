#!/bin/bash
#goldyck@vmware.com

#This script adds a given number of ESXi hosts to an existing cPOD.

# $1 : Name of cpod to modify
# $2 : Number of ESXi hosts to add
# $3 : Name of owner

# source helper functions
. ./env
source ./extra/functions.sh

#logging 
#LOGGING="FALSE"
if [ -z "$LOGGING" ]
then
    echo "enabling logging"
    export LOGGING="TRUE"
    /usr/bin/script /tmp/scripts/test-$$-log.txt /bin/bash -c "$0 $*"
    exit 0
fi

#start the timer
START=$( date +%s )

#input validation check
if [ $# -ne 3 ]; then
  echo "usage: $0 <name_of_cpod>  <#esx to add> <name_of_owner>"
  echo "usage example: $0 LAB01 4 vedw" 
  exit 1  
fi

if [ -z "$1" ] || [ -z "$2"  ] || [ -z "$3"  ];then 
  echo "usage: $0 <name_of_cpod>  <#esx to add> <name_of_owner>"
  echo "usage example: $0 LAB01 4 vedw" 
  exit 1
fi

if [[ "$2" -ge 1 && "$2" -le 20 ]]; then
    echo "$2 is between 1 and 20...good!"
else
    echo "$2 is not between 1 and 20, don't be greedy"
    exit 1
fi

if [ "$TERM" = "screen" ] && [ -n "$TMUX" ]; then
  echo "You are running in a tmux session. That is very wise of you !  :)"
else
  echo "You are not running in a tmux session. Maybe you want to run this in a tmux session?"
  echo "stopping script because you're not in a TMUX session."
  exit 1
fi

###########
#main code#
###########

#TODO check_space

#build the variables

CPODROUTER=$( echo "${HEADER}-${1}" | tr '[:upper:]' '[:lower:]' )
NAME_UPPER=$( echo "${1}" | tr '[:lower:]' '[:upper:]' )
LASTNUMESX=$(get_last_ip  "esx"  "${CPODROUTER}")
STARTNUMESX=$(( LASTNUMESX-20+1 ))
NUM_ESX="${2}"
OWNER="${3}"
SUBNET=$( ./"${COMPUTE_DIR}"/cpod_ip.sh "${1}" )
PORTGROUP_NAME="${CPODROUTER}"
TRANSIT_IP=$( grep "${CPODROUTER}" "/etc/hosts" | awk '{print $1}' )
GEN_PASSWORD=$( grep "${CPODROUTER}" "/etc/hosts" | awk '{print $4}' )
DOMAIN="${CPODROUTER}.${ROOT_DOMAIN}"

#check for duplicate IP's
for ((i=1; i<=NUM_ESX; i++)); do
  OCTET=$(( LASTNUMESX+i ))
  IP="${SUBNET}.${OCTET}"
  echo "checking for duplicate ip on $IP..."
  STATUS=$( ping -c 1 "${IP}" 2>&1 > /dev/null ; echo $? )
  STATUS=$(( "$STATUS" ))
  if [ "${STATUS}" == 0 ]; then
          echo "Error: Something has the same IP."
          exit 1
  fi
done

# have the hosts created with respool_create
echo "Adding $NUM_ESX ESXi hosts to $NAME_UPPER owned by $OWNER on portgroup: $PORTGROUP_NAME in domain: $ROOT_DOMAIN starting at: $STARTNUMESX."
"${COMPUTE_DIR}"/create_resourcepool.sh "${NAME_UPPER}" "${PORTGROUP_NAME}" "${TRANSIT_IP}" "${NUM_ESX}" "${ROOT_DOMAIN}" "${OWNER}" "${STARTNUMESX}"


#Configure ESX hosts

for ((i=1; i<=NUM_ESX; i++)); do
  #configure the hosts
  OCTET=$(( LASTNUMESX+i ))
  IP="${SUBNET}.${OCTET}"
  HOST=$( printf "%02d" "${STARTNUMESX}" )
  ESXHOST="esx${HOST}"
  VMNAME="cPOD-${NAME_UPPER}-${ESXHOST}"

  #wait for DHCPIP to become available - Endless Loop potenial
  while [ -z "$DHCPIP" ]
    do
        # code to be executed while $DHCPIP is empty
        echo "Waiting for $ESXHOST to get a DHCP IP..."
        DHCPIP=$( govc vm.ip "$VMNAME" )
    done
  
  #wait for ESXCLI to become available - Endless Loop potenial
  while ! ssh -q -o "BatchMode=yes" -o "ConnectTimeout=5" -p $DHCPIP 22 exit >/dev/null 2>&1; do
      echo "Waiting for $ESXHOST to respond to SSH on $DHCPIP..."
      sleep 5
  done

  echo "$HOST is now responding to SSH."

  
  #update the host
  echo "=========================================="
  echo "== Configuring $ESXHOST on IP: $DHCPIP  =="
  echo "=========================================="
	echo "$ESXHOST --- Setting hostname ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli system hostname set --host=${NAME} --domain=${DOMAIN}" 
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli system settings advanced set -o /UserVars/SuppressCoredumpWarning -i 1"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "echo \"server ${CPODROUTER} iburst\" >> /etc/ntp.conf ; chkconfig ntpd on ; /etc/init.d/ntpd stop ; /etc/init.d/ntpd start"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli system ntp set --reset ; esxcli system ntp set -s ${CPODROUTER} --enabled true"
	echo "$ESXHOST --- setting dns to $DOMAIN ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli network ip dns server add -s ${CPODROUTER}"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli network ip dns search add -d ${DOMAIN}"
	echo "$ESXHOST --- setting ssd with ssdcript in ./install/ssd_esx_tag.sh ---"
	sshpass -p "${ROOT_PASSWD}" scp -o StrictHostKeyChecking=no ./install/ssd_esx_tag.sh root@"${DHCPIP}":/tmp/ssd_esx_tag.sh
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "/tmp/ssd_esx_tag.sh"
	echo "$ESXHOST --- setting password ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "printf \"${GEN_PASSWORD}\n${GEN_PASSWORD}\n\" | passwd root "
	echo "$ESXHOST --- setting host IP to: $IP ---"
	sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${DHCPIP}" "esxcli network ip interface ipv4 set -i vmk0 -I ${IP} -N 255.255.255.0 -t static ; esxcli network ip interface set -e false -i vmk0 ; esxcli network ip interface set -e true -i vmk0"

	#Go into this loop for ESXi based image, adding NFS datastore and VMotion interface and ISO bank
	if [ "${NOCUSTO}" != "YES" ]; then
		echo "$ESXHOST --- setting vmotion on vmk0 ---"
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${IP}" "vim-cmd hostsvc/vmotion/vnic_set vmk0"
		echo "Adding nfsDatastore from cpodrouter"
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli storage nfs add --host=${CPODROUTER} --share=/data/Datastore --volume-name=nfsDatastore" 
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli storage nfs list "

		if [ "${ISO_BANK_SERVER}" != "" ]; then
			echo "Adding BITS from ${ISO_BANK_SERVER}"
			sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli storage nfs add --host=${ISO_BANK_SERVER} --share=${ISO_BANK_DIR} --volume-name=BITS -r" 
		fi
	fi
	echo "restarting services"
	sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no root@"${IP}" "/sbin/generate-certificates ; /etc/init.d/hostd restart && /etc/init.d/vpxa restart"

  #update DNS
  echo "adding IP $IP for host $ESXHOST on $CPODROUTER"
  add_to_cpodrouter_hosts "${IP}" "${ESXHOST}" "${CPODROUTER}"
  #set the next esxi for next loop
  STARTNUMESX=$(( STARTNUMESX+1 ))
done

#end the timer and wrapup
END=$( date +%s )
TIME=$(( "${END}" - "${START}" ))

echo
echo "============================="
echo "===  creation is finished ==="
echo "=== In ${TIME} Seconds ==="
echo "============================="

export LOGGING=""