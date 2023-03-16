#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == "" ] && echo "usage: ${0} <cPod Name> <owner email>" && exit 1

if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### Local vars ####

HOSTNAME=${HOSTNAME_VCSA}
NAME=${NAME_VCSA}
IP=${IP_VCSA}
OVA=${OVA_VCSA}

#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        echo "Error: You're not allowed to deploy"
        ./extra/post_slack.sh ":wow: *${2}* you're not allowed to deploy in *${NAME_HIGHER}*"
        exit 1
fi

STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        ./extra/post_slack.sh ":wow: Are you sure that VCSA is not already deployed in ${1}. Something have the same @IP."
        exit 1
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

./extra/post_slack.sh "Deploying a new VCSA for *${1}*. We're working for you, it takes ages. Stay tuned..."

export MYSCRIPT=/tmp/$$

if [ "${VCSA_PLACEMENT}" == "ATSIDE" ]; then

	VAPP="cPod-${NAME_HIGHER}"
	NAME="${VAPP}-vcsa"
	DATASTORE=${VCENTER_DATASTORE}

	case "${BACKEND_NETWORK}" in
		NSX-V)
			PORTGROUP=$( ${NETWORK_DIR}/list_logicalswitch.sh ${NSX_TRANSPORTZONE} | jq 'select(.name == "'${CPOD_NAME_LOWER}'") | .portgroup' | sed 's/"//g' )
			CPOD_PORTGROUP=$( ${COMPUTE_DIR}/list_portgroup.sh | jq 'select(.network == "'${PORTGROUP}'") | .name' | sed 's/"//g' )
			;;
		NSX-T)
			CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
			echo ">>> ${CPOD_PORTGROUP}"
			;;
		VLAN)
			CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
			;;
	esac

	cat << EOF > ${MYSCRIPT}
	export LANG=en_US.UTF-8
	cd /root/cPodFactory/ovftool
	./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --X:enableHiddenProperties \
	--sourceType=OVA --allowExtraConfig --acceptAllEulas --X:injectOvfEnv --skipManifestCheck \
	--X:waitForIp --X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
	--name=${NAME} --datastore=${DATASTORE} --prop:guestinfo.cis.deployment.autoconfig=True \
	--powerOn --noSSLVerify --prop:guestinfo.cis.deployment.node.type=embedded --deploymentOption=small \
	--diskMode=thin --net:"Network 1"="${CPOD_PORTGROUP}" --prop:guestinfo.cis.appliance.net.prefix=24 \
	--prop:guestinfo.cis.system.vm0.port=443 --prop:guestinfo.cis.appliance.net.gateway=${GATEWAY} \
	--prop:guestinfo.cis.appliance.root.passwd=${PASSWORD} --prop:guestinfo.cis.appliance.net.dns.servers=${DNS} \
	--prop:guestinfo.cis.appliance.net.mode=static --prop:guestinfo.cis.vmdir.domain-name=${AUTH_DOMAIN} \
	--prop:guestinfo.cis.ceip_enabled=False --prop:guestinfo.cis.appliance.ssh.enabled=True \
	--prop:guestinfo.cis.appliance.net.addr.family=ipv4 --prop:guestinfo.cis.appliance.ntp.servers=${NTP} \
	--prop:guestinfo.cis.appliance.net.pnid=${HOSTNAME}.${DOMAIN} --prop:guestinfo.cis.vmdir.first-instance=True \
	--prop:guestinfo.cis.appliance.net.addr=${IP} --prop:guestinfo.cis.vmdir.password=${PASSWORD} ${OVA} \
	'vi://${VCENTER_ADMIN}:${VCENTER_PASSWD}@${VCENTER}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}'
EOF

else

	cat << EOF > ${MYSCRIPT}
	export LANG=en_US.UTF-8
	cd /root/cPodFactory/ovftool
	./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --X:enableHiddenProperties \
	--sourceType=OVA --allowExtraConfig --acceptAllEulas --X:injectOvfEnv --skipManifestCheck \
	--X:waitForIp --X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
	--name=${NAME} --datastore=${DATASTORE} --powerOn --noSSLVerify \
	--diskMode=thin --net:"Network 1"="VM Network" \
	--prop:guestinfo.cis.appliance.net.addr.family="ipv4" \
	--prop:guestinfo.cis.appliance.net.mode="static" \
	--prop:guestinfo.cis.appliance.net.addr="${IP}" \
	--prop:guestinfo.cis.appliance.net.prefix="24" \
	--prop:guestinfo.cis.appliance.net.gateway="${GATEWAY}" \ 
	--prop:guestinfo.cis.appliance.net.dns.servers="${DNS}" \
	--prop:guestinfo.cis.appliance.net.pnid="${HOSTNAME}.${DOMAIN}" \
	--prop:guestinfo.cis.vmdir.password="${PASSWORD}" \
	--prop:guestinfo.cis.appliance.root.passwd="${PASSWORD}" \
	--prop:guestinfo.cis.vpxd.ha.management.addr="${HOSTNAME}.${DOMAIN}" \
	--prop:guestinfo.cis.vpxd.ha.management.port="443" \
	--prop:guestinfo.cis.vpxd.ha.management.user="root" \
	--prop:guestinfo.cis.vpxd.ha.management.password="${PASSWORD}" \
	--prop:guestinfo.cis.ceip_enabled=False \
	--prop:domain="${HOSTNAME}.${DOMAIN}" \
	--prop:searchpath="${DOMAIN}" \
	vi://root:${PASSWORD}@${SUBNET}.21:443
EOF

fi

bash ${MYSCRIPT}

ONCE=0
STATUS="RUNNING"
while [ "${STATUS}" != "SUCCEEDED" ]
do
	sleep 5
	echo "Installing..."
	#STATUS=$( curl -s -k -u administrator@${AUTH_DOMAIN}:${PASSWORD} -X GET https://${SUBNET}.3:5480/rest/vcenter/deployment | jq '.status' | sed 's/"//g' )
	STATUS=$( curl -s -k -u administrator@${AUTH_DOMAIN}:${PASSWORD} -X GET https://${SUBNET}.3:5480/rest/vcenter/deployment )
	echo ${STATUS} | grep ".status" 2>&1 > /dev/null && STATUS=$( echo ${STATUS} | jq '.status' | sed 's/"//g' )	
	
	if [ "${STATUS}" == "RUNNING" ] && [ ${ONCE} -eq 0 ]; then
		ONCE=1
		./extra/post_slack.sh ":speech_balloon: You can follow vCenter deployment through <https://vcsa.${DOMAIN}:5480|VCSA admin URL> for cPod *${1}*"
		echo "Follow the deployment trough https://vcsa.${DOMAIN}:5480"
	fi
done	

echo "SUCCEEDED !"

./extra/post_slack.sh ":speech_balloon: Customizing <https://vcsa.${DOMAIN}|VCSA> for cPod *${1}*, almost finished!"
CPOD="${1}"
CPOD_LOWER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )
NUMESX=$( ssh -o "StrictHostKeyChecking no" root@cpod-${CPOD_LOWER} "grep esx /etc/hosts | wc -l" )
./compute/prep_vcsa.sh ${CPOD} ${NUMESX}

./extra/post_slack.sh ":thumbsup: <https://vcsa.${DOMAIN}|VCSA> for cPod *${1}* seems ready!"

rm ${MYSCRIPT}
