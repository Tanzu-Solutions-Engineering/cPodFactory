#!/bin/bash
#edewitte@vmware.com

# sourcing params and functions

source ./env 
source ./govc_env
source ./extra/functions.sh


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
        exit 1
fi

echo "Testing if something is not using the same @IP..."
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
        exit 1
fi
echo "It seems all good, let's deploy ova."

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )
#echo ${PASSWORD}

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
			;;
		VLAN)
			CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
			;;
	esac

	cat << EOF > ${MYSCRIPT}
	export LANG=en_US.UTF-8
	cd /root/cPodFactory/ovftool
	./ovftool --acceptAllEulas --X:injectOvfEnv --allowExtraConfig --X:enableHiddenProperties \
	--overwrite \
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
	--overwrite \
	--sourceType=OVA --allowExtraConfig --acceptAllEulas --X:injectOvfEnv --skipManifestCheck \
	--X:waitForIp --X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \
	--name=${NAME} --datastore=${DATASTORE} --prop:guestinfo.cis.deployment.autoconfig=True \
	--powerOn --noSSLVerify --prop:guestinfo.cis.deployment.node.type=embedded --deploymentOption=tiny \
	--diskMode=thin --net:"Network 1"="VM Network" --prop:guestinfo.cis.appliance.net.prefix=24 \
	--prop:guestinfo.cis.system.vm0.port=443 --prop:guestinfo.cis.appliance.net.gateway=${GATEWAY} \
	--prop:guestinfo.cis.appliance.root.passwd=${PASSWORD} --prop:guestinfo.cis.appliance.net.dns.servers=${DNS} \
	--prop:guestinfo.cis.appliance.net.mode=static --prop:guestinfo.cis.vmdir.domain-name=${AUTH_DOMAIN} \
	--prop:guestinfo.cis.ceip_enabled=False --prop:guestinfo.cis.appliance.ssh.enabled=True \
	--prop:guestinfo.cis.appliance.net.addr.family=ipv4 --prop:guestinfo.cis.appliance.ntp.servers=${NTP} \
	--prop:guestinfo.cis.appliance.net.pnid=${HOSTNAME}.${DOMAIN} --prop:guestinfo.cis.vmdir.first-instance=True \
	--prop:guestinfo.cis.appliance.net.addr=${IP} --prop:guestinfo.cis.vmdir.password=${PASSWORD} ${OVA} \
	vi://root:${PASSWORD}@${SUBNET}.21:443
EOF

fi

bash ${MYSCRIPT}

add_to_cpodrouter_hosts ${IP} vcsa ${CPOD_NAME}
restart_cpodrouter_dnsmasq ${CPOD_NAME}

echo

ONCE=0
STATUS=""
PREVIOUSSTAGE=""
JQRESPONSE=""
printf "Installing VCSA "
while [ "${STATUS}" != "SUCCEEDED" ]
do
	RESPONSE=$(curl -s -k -w '####%{response_code}' -u root:${PASSWORD} -X GET https://${IP}:5480/rest/vcenter/deployment )
	HTTPSTATUS=$(echo ${RESPONSE} |awk -F '####' '{print $2}')
	if [ $HTTPSTATUS -eq 200 ]
	then
		JQRESPONSE=$(echo ${RESPONSE} |awk -F '####' '{print $1}')
	else
		STAMP=$(date +'%F-%T')
		echo "${RESPONSE}" > /tmp/response-$STAMP
	fi
	echo ${JQRESPONSE} | grep ".status" 2>&1 > /dev/null && STATUS=$( echo ${JQRESPONSE} | jq -r '.status')	
	STAGE=$(echo ${JQRESPONSE} | jq -r '.progress.message.default_message')
	if [ "${STATUS}" == "RUNNING" ] && [ ${ONCE} -eq 0 ]; then
		ONCE=1
		echo "Follow the deployment trough https://vcsa.${DOMAIN}:5480 - root pwd : ${PASSWORD}"
		printf "Installing VCSA "
	fi
	if [ "${STAGE}" != "${PREVIOUSSTAGE}" ]; then
		printf "\n\t %s" "${STAGE}"
		PREVIOUSSTAGE=${STAGE}
	fi
    printf '.' >/dev/tty
	sleep 5
done	
echo
echo "VCSA Installation SUCCEEDED !"
#sleep 60
#rm ${MYSCRIPT}
