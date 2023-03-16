#!/bin/bash
#bdereims@vmware.com

DHCP_LEASE=/var/lib/misc/dnsmasq.leases
DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts
PASSWORD="###ROOT_PASSWD###"
GEN_PASSWORD="###GEN_PASSWD###"
ISO_BANK_SERVER="###ISO_BANK_SERVER###"
ISO_BANK_DIR="###ISO_BANK_DIR###"
NUM_ESX="###NUM_ESX###"
NOCUSTO="###NOCUSTO###"
DOMAIN=$( grep "domain=" /etc/dnsmasq.conf | sed "s/domain=//" )

[ "$( hostname )" == "mgmt-cpodrouter" ] && exit 1
[ -f already_prep ] && exit 0

touch already_prep
systemctl restart ntpd

# waiting for all ESX get lease, boot takes time
ISTHERE=0
NUM_ESX=$( expr ${NUM_ESX} )
while [ ${ISTHERE} != ${NUM_ESX} ]
do
	sleep 3 
	ISTHERE=$( cat ${DHCP_LEASE} | cut -d ' ' -f2 | sort -u | wc -l )
	if [ "${ISTHERE}X" == "X" ]; then
		ISTHERE=0
	fi
done

echo "Configuring cPodRouter nfs server"

touch /data/Datastore/exclude.tag

mkdir -p /data/Datastore/scratch/log
chown -R nobody:65534 /data/Datastore/scratch

sed -i "s#ExecStart=/usr/sbin/rpc.nfsd $RPCNFSDARGS#ExecStart=/usr/sbin/rpc.nfsd 12 $RPCNFSDARGS#" /usr/lib/systemd/system/nfs-server.service
systemctl daemon-reload
systemctl stop nfs-server ; systemctl start nfs-server

if [ ${NUM_ESX} -ge 1 ]; then
	echo "waiting a bit ..."
	sleep 160
fi

I=$( cat ${DHCP_LEASE} | wc -l )
for ESX in $( cat ${DHCP_LEASE} | cut -f 2,3 -d' ' | sed 's/\ /,/' ); do
	IP=$( echo ${ESX} | cut -f2 -d',' )
	BASEIP=$( echo ${IP} | sed 's/\.[0-9]*$/./' )
	CPODROUTER="${BASEIP}1"
	NEWIP=$( expr ${I} + 20 )
	NEWIP="${BASEIP}${NEWIP}"
	NAME=$( printf "esx%02d" ${I} )
	printf "${NEWIP}\t${NAME}\n" >> ${HOSTS}
	I=$( expr ${I} - 1 )
	echo "Configuring ${NAME}..."
	echo "Setting hostname"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system hostname set --host=${NAME} --domain=${DOMAIN}" 2>&1 > /dev/null
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system settings advanced set -o /Mem/ShareForceSalting -i 0" 2>&1 > /dev/null
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system settings advanced set -o /UserVars/SuppressCoredumpWarning -i 1" 2>&1 > /dev/null

	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "echo \"server ${CPODROUTER} iburst\" >> /etc/ntp.conf ; chkconfig ntpd on ; /etc/init.d/ntpd stop ; /etc/init.d/ntpd start" 2>&1 > /dev/null
	#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system ntp set --reset ; esxcli system ntp set -s 172.16.1.1 --enabled true" 2>&1 > /dev/null
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system ntp set --reset ; esxcli system ntp set -s ${CPODROUTER} --enabled true" 2>&1 > /dev/null
	#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "echo \"nameserver ${CPODROUTER}\" > /etc/resolv.conf ; echo \"search ${DOMAIN}\" >> /etc/resolv.conf" 2>&1 > /dev/null
	echo "setting dns"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip dns server add -s ${CPODROUTER}" 2>&1 > /dev/null
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip dns search add -d ${DOMAIN}" 2>&1 > /dev/null
	echo "setting ssd"
	sshpass -p ${PASSWORD} scp -o StrictHostKeyChecking=no /root/update/ssd_esx_tag.sh root@${IP}:/tmp/ssd_esx_tag.sh 2>&1 > /dev/null
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "/tmp/ssd_esx_tag.sh" 2>&1 > /dev/null

	echo "changing password"
	sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "printf \"${GEN_PASSWORD}\n${GEN_PASSWORD}\n\" | passwd root " 2>&1 > /dev/null

	echo "changing host ip"
	sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli network ip interface ipv4 set -i vmk0 -I ${NEWIP} -N 255.255.255.0 -t static ; esxcli network ip interface set -e false -i vmk0 ; esxcli network ip interface set -e true -i vmk0" 2>&1 > /dev/null

	#Go into this loop for ESXi based image, adding NFS datastore and VMotion interface and ISO bank
	if [ "${NOCUSTO}" != "YES" ]; then
		echo "setting vmotion on vmk0"
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "vim-cmd hostsvc/vmotion/vnic_set vmk0" 2>&1 > /dev/null
		echo "Adding nfsDatastore from cpodrouter"
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs add --host=${CPODROUTER} --share=/data/Datastore --volume-name=nfsDatastore"  2>&1 > /dev/null
		sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs list "

		if [ "${ISO_BANK_SERVER}" != "" ]; then
			echo "Adding BITS from ${ISO_BANK_SERVER}"
			sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "esxcli storage nfs add --host=${ISO_BANK_SERVER} --share=${ISO_BANK_DIR} --volume-name=BITS -r"  2>&1 > /dev/null
		fi
	fi

	sshpass -p ${GEN_PASSWORD} ssh -o StrictHostKeyChecking=no root@${NEWIP} "/sbin/generate-certificates ; /etc/init.d/hostd restart && /etc/init.d/vpxa restart" 2>&1 > /dev/null
done

# Create entry for VCSA
if [ ${NUM_ESX} -ge 1 ]; then
	printf "${BASEIP}3\tvcsa\n" >> ${HOSTS}
fi

# Optionnal
#printf "${BASEIP}4\tnsx\n" >> ${HOSTS}
#printf "#${BASEIP}5-7\tnsx controllers\n" >> ${HOSTS}
#printf "${BASEIP}8\tedge\n" >> ${HOSTS}

systemctl stop dnsmasq ; systemctl start dnsmasq 

echo "root:${GEN_PASSWORD}" | chpasswd
