#!/bin/bash
#goldyck@vmware.com

DHCP_LEASE=/var/lib/misc/dnsmasq.leases
PASSWORD="###ROOT_PASSWD###"
GEN_PASSWORD="###GEN_PASSWD###"
ISO_BANK_SERVER="###ISO_BANK_SERVER###"
ISO_BANK_DIR="###ISO_BANK_DIR###"
NUM_ESX="###NUM_ESX###"
NOCUSTO="###NOCUSTO###"
DOMAIN=$( grep "domain=" /etc/dnsmasq.conf | sed "s/domain=//" )


# waiting for all ESX get lease, boot takes time
ISTHERE=0
while [ "${ISTHERE}" != ${NUM_ESX} ]
do
	sleep 3 
	ISTHERE=$( cat ${DHCP_LEASE} | cut -d ' ' -f2 | sort -u | wc -l )
	# this is a very complicated way of setting ISTHERE to 0 if ISTHERE is empty
	if [ "${ISTHERE}X" == "X" ]; then
		ISTHERE=0
	fi
done

if [ ${NUM_ESX} -ge 1 ]; then
	echo "waiting a bit ..."
	sleep 160
fi

I=$( cat ${DHCP_LEASE} | wc -l )
for ESX in $( cat ${DHCP_LEASE} | cut -f 2,3 -d' ' | sed 's/\ /,/' ); do
	IP=$( echo "${ESX}" | cut -f2 -d',' )
	BASEIP=$( echo "${IP}" | sed 's/\.[0-9]*$/./' )
	CPODROUTER="${BASEIP}1"
	NEWIP=$(( I + 20 ))
	NEWIP="${BASEIP}${NEWIP}"
	NAME=$( printf "esx%02d" "${I}" )
	I=$(( I - 1 ))
	echo "Configuring ${NAME}..."
	echo "Setting hostname"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli system hostname set --host=${NAME} --domain=${DOMAIN}" 
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli system settings advanced set -o /UserVars/SuppressCoredumpWarning -i 1"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@"${IP}" "echo \"server ${CPODROUTER} iburst\" >> /etc/ntp.conf ; chkconfig ntpd on ; /etc/init.d/ntpd stop ; /etc/init.d/ntpd start"
	#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system ntp set --reset ; esxcli system ntp set -s 172.16.1.1 --enabled true"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@"${IP}" "esxcli system ntp set --reset ; esxcli system ntp set -s ${CPODROUTER} --enabled true"
	#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "echo \"nameserver ${CPODROUTER}\" > /etc/resolv.conf ; echo \"search ${DOMAIN}\" >> /etc/resolv.conf"
	echo "setting dns"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip dns server add -s ${CPODROUTER}"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip dns search add -d ${DOMAIN}"
	echo "setting ssd"
	sshpass -p ${PASSWORD} scp -o StrictHostKeyChecking=no /root/update/ssd_esx_tag.sh root@${IP}:/tmp/ssd_esx_tag.sh
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "/tmp/ssd_esx_tag.sh"
	echo "changing password"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "printf \"${GEN_PASSWORD}\n${GEN_PASSWORD}\n\" | passwd root "
	echo "changing host ip"
	sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip interface ipv4 set -i vmk0 -I ${NEWIP} -N 255.255.255.0 -t static ; esxcli network ip interface set -e false -i vmk0 ; esxcli network ip interface set -e true -i vmk0"

	#Go into this loop for ESXi based image, adding NFS datastore and VMotion interface and ISO bank
	if [ "${NOCUSTO}" != "YES" ]; then
		echo "setting vmotion on vmk0"
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "vim-cmd hostsvc/vmotion/vnic_set vmk0"
		echo "Adding nfsDatastore from cpodrouter"
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs add --host=${CPODROUTER} --share=/data/Datastore --volume-name=nfsDatastore" 
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs list "

		if [ "${ISO_BANK_SERVER}" != "" ]; then
			echo "Adding BITS from ${ISO_BANK_SERVER}"
			sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs add --host=${ISO_BANK_SERVER} --share=${ISO_BANK_DIR} --volume-name=BITS -r" 
		fi
	fi
	echo "restarting services"
	sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "/sbin/generate-certificates ; /etc/init.d/hostd restart && /etc/init.d/vpxa restart"
done
