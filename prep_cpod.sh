#!/bin/bash
#bdereims@vmware.com

# source helper functions
. ./env
source ./extra/functions.sh

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod> <#_of_esx>" && exit 1 

HOSTS=/etc/hosts
GEN_PASSWD=$( ./extra/passwd_for_cpod.sh ${1} )


CPODROUTER=$( echo "${HEADER}-${1}" | tr '[:upper:]' '[:lower:]' )
NAME_UPPER=$( echo "${1}" | tr '[:lower:]' '[:upper:]' )

NUM_ESX="${2}"
STARTNUMESX=1
LASTNUMESX=20
SUBNET=$( ./"${COMPUTE_DIR}"/cpod_ip.sh "${1}" )
#PORTGROUP_NAME="${CPODROUTER}"
TRANSIT_IP=$( grep "${CPODROUTER}" "/etc/hosts" | awk '{print $1}' )
GEN_PASSWORD=$( grep "${CPODROUTER}" "/etc/hosts" | awk '{print $4}' )
DOMAIN="${CPODROUTER}.${ROOT_DOMAIN}"

# have the hosts created with respool_create
#echo "Adding $NUM_ESX ESXi hosts to $NAME_UPPER owned by $OWNER on portgroup: $PORTGROUP_NAME in domain: $ROOT_DOMAIN starting at: $STARTNUMESX."
#"${COMPUTE_DIR}"/create_resourcepool.sh "${NAME_UPPER}" "${PORTGROUP_NAME}" "${TRANSIT_IP}" "${NUM_ESX}" "${ROOT_DOMAIN}" "${OWNER}" "${STARTNUMESX}"


#Configure ESX hosts. As we execute this from the cPodRouter, we do not want the SSH keys added to known hosts.

for ((i=1; i<=NUM_ESX; i++)); do
  #configure the hosts
  OCTET=$(( LASTNUMESX+i ))
  IP="${SUBNET}.${OCTET}"
  HOST=$( printf "%02d" "${STARTNUMESX}" )
  ESXHOST="esx${HOST}"
  VMNAME="cPod-${NAME_UPPER}-${ESXHOST}"
  DHCPIP=""
  SSHOK=1
  TIMEOUT=0
  
  #wait for DHCPIP to become available 

  while [ -z "$DHCPIP" ]
  do
    # code to be executed while $DHCPIP is empty
    echo "Waiting for $ESXHOST to get a DHCP IP..."
    DHCPIP=$( govc vm.ip -v4 "$VMNAME" )
    echo "DHCPIP is now: $DHCPIP"
    sleep 10
    TIMEOUT=$((TIMEOUT + 1))
    if [ $TIMEOUT -ge 20 ]; then
      echo "bailing out..."
      exit 1  
    fi      
  done
  
  #wait for ESXCLI to become available 
  while [ "$SSHOK" != 0 ]
  do  
    SSHOK=$( sshpass -p "${ROOT_PASSWD}" ssh -o "StrictHostKeyChecking=no" -o "ConnectTimeout=5" -o "UserKnownHostsFile=/dev/null" -o "LogLevel=error" root@"${DHCPIP}" exit >/dev/null 2>&1; echo $? ) 
    echo "SSH is not ready on $DHCPIP ===$SSHOK==="
    sleep 10
    TIMEOUT=$((TIMEOUT + 1))
    if [ $TIMEOUT -ge 20 ]; then
      echo "bailing out..."
      exit 1  
    fi 
  done

  echo "$ESXHOST is now responding to SSH... Ready to proceed"

  #update the host
  echo "=========================================="
  echo "== Configuring $ESXHOST on IP: $DHCPIP  =="
  echo "=========================================="
	echo "$ESXHOST --- Setting hostname to $ESXHOST and domain to: $DOMAIN   ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli system hostname set --host=${ESXHOST} --domain=${DOMAIN}" 
  echo "$ESXHOST --- Setting MemorySalting and Coredump  ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli system settings advanced set -o /UserVars/SuppressCoredumpWarning -i 1"
  echo "$ESXHOST --- Setting ntp to: $TRANSIT_IP  ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "echo \"server ${TRANSIT_IP} iburst\" >> /etc/ntp.conf ; chkconfig ntpd on ; /etc/init.d/ntpd stop ; /etc/init.d/ntpd start"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli system ntp set --reset ; esxcli system ntp set -s ${TRANSIT_IP} --enabled true"
	echo "$ESXHOST --- setting dns to: $TRANSIT_IP and domain to: $DOMAIN ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli network ip dns server add -s ${TRANSIT_IP}"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli network ip dns search add -d ${DOMAIN}"
	echo "$ESXHOST --- setting ssd with ssdcript in ./install/ssd_esx_tag.sh ---"
	sshpass -p "${ROOT_PASSWD}" scp -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error ./install/ssd_esx_tag.sh root@"${DHCPIP}":/tmp/ssd_esx_tag.sh
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "sh /tmp/ssd_esx_tag.sh"
	echo "$ESXHOST --- setting password ---"
	sshpass -p "${ROOT_PASSWD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "printf \"${GEN_PASSWORD}\n${GEN_PASSWORD}\n\" | passwd root "
	echo "$ESXHOST --- setting host IP to final IP: $IP ---"
	sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${DHCPIP}" "esxcli network ip interface ipv4 set -i vmk0 -I ${IP} -N 255.255.255.0 -t static ; esxcli network ip interface set -e false -i vmk0 ; esxcli network ip interface set -e true -i vmk0"

	#Go into this loop for ESXi based image, adding NFS datastore and VMotion interface and ISO bank
	if [ "${NOCUSTO}" != "YES" ]; then
		echo "$ESXHOST --- setting vmotion on vmk0 ---"
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${IP}" "vim-cmd hostsvc/vmotion/vnic_set vmk0"
		echo "Adding nfsDatastore from cpodrouter"
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${IP}" "esxcli storage nfs add --host=${TRANSIT_IP} --share=/data/Datastore --volume-name=nfsDatastore" 
		sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${IP}" "esxcli storage nfs list"

  #this is not working ISO_BANK_SERVER does not exist!
  #		if [ "${ISO_BANK_SERVER}" != "" ]; then
  #			echo "Adding BITS from ${ISO_BANK_SERVER}"
  #			sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${IP}" "esxcli storage nfs add --host=${ISO_BANK_SERVER} --share=${ISO_BANK_DIR} --volume-name=BITS -r" 
  #		fi
	fi

	echo "restarting services"
	sshpass -p "${GEN_PASSWORD}" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o LogLevel=error root@"${IP}" "/sbin/generate-certificates ; /etc/init.d/hostd restart && /etc/init.d/vpxa restart"

  #we want to SSH once from the cpodrouter to save the fingerprint
  ssh -o LogLevel=error -o StrictHostKeyChecking=no root@"$CPODROUTER" "sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o LogLevel=error root@${IP} exit"
  
  #update DNS
  echo "adding IP $IP for host $ESXHOST on $CPODROUTER"
  add_to_cpodrouter_hosts "${IP}" "${ESXHOST}" "${CPODROUTER}"
  #set the next esxi for next loop
  STARTNUMESX=$(( STARTNUMESX+1 ))
done
