#!/bin/bash
#bdereims@vmware.com

. ./env

[ "${1}" == ""  -o "${2}" == "" ] && echo "usage: ${0}  <CPOD name> <Path to OVA>" && exit 1


if [ -f "${1}" ]; then
        . ./${COMPUTE_DIR}/"${1}"
else
        SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )

        [ $? -ne 0 ] && echo "error: file or env '${1}' does not exist" && exit 1

        CPOD=${1}
	unset DATASTORE
        . ./${COMPUTE_DIR}/cpod-xxx_env
fi

### Functions ###

guess_param() {
	# ${1} string to look into for known parameters
	return_value=""
	case ${1} in
		*"ceip"*)
			return_value="False"
			;;
		*"net.mode"*)
			return_value="static"
			;;
		*"addr.family"*)
			return_value="ipv4"
			;;
		*"ip"*|*"addr"*)
			return_value=${IP}
			;;
		*"prefix"*)
			return_value="24"
			;;
		*"netmask"*)
			return_value="255.255.255.0"
			;;
		*"gateway"*|*"default_gw"*|*"default-gw"*)
			return_value=${GATEWAY}
			;;
		*"hostname"*|*"fqdn"*)
			return_value=${HOSTNAME}.${DOMAIN}
			;;
		*"dns_domain"*|*"dnsDomain"*|*"DOMAIN"*|*"searchpath"*|*"domain"*)
			return_value=${DOMAIN}
			;;
		*"dns_server"*|*"DNS"*|*"dns"*)
			return_value=${GATEWAY}
			;;
		*"ntp"*|*"NTP"*)
			return_value=${GATEWAY}
			;;
		*"password"*|*"passwd"*|*"pwd"*)
			return_value=${PASSWORD}
			;;
esac
	echo $return_value   
}

### Local vars ###

echo "enter hostname for vm"
read HOSTNAME
HOSTNAME=$( echo ${HOSTNAME} | tr '[:upper:]' '[:lower:]' )

echo "enter last bit for ip address. (it will be {cpod-subnet}.[lastbit])"
read IPLASTBIT
SUBNET=$( ./${COMPUTE_DIR}/cpod_ip.sh ${1} )
IP=${SUBNET}.${IPLASTBIT}

OVA=${2}
if [ -f "${OVA}" ]; then
        echo "	ok - ${OVA}"
else
        echo "	File NOT FOUND -  ${OVA}"
        exit
fi


#AUTH_DOMAIN="vsphere.local"
AUTH_DOMAIN=${DOMAIN}

###################

CPOD_NAME="cpod-$1"
NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )

CPOD_PORTGROUP="${CPOD_NAME_LOWER}"
VAPP="cPod-${NAME_HIGHER}"
NAME="${VAPP}-${HOSTNAME}"
STATUS=$( ping -c 1 ${IP} 2>&1 > /dev/null ; echo $? )
STATUS=$(expr $STATUS)
if [ ${STATUS} == 0 ]; then
        echo "Error: Something has the same IP."
#        ./extra/post_slack.sh ":wow: Are you sure that VCSA is not already deployed in ${1}. Something have the same @IP."
        exit 1
fi

PASSWORD=$( ./${EXTRA_DIR}/passwd_for_cpod.sh ${1} )

export MYSCRIPT=/tmp/$$

#========= 

echo "export LANG=en_US.UTF-8" > ${MYSCRIPT}
echo "cd /root/cPodFactory/ovftool" >> ${MYSCRIPT}

echo './ovftool --acceptAllEulas  --X:enableHiddenProperties \'  >> ${MYSCRIPT} 
echo '--sourceType=OVA --allowExtraConfig --acceptAllEulas --X:injectOvfEnv  \'  >> ${MYSCRIPT}
echo '--X:waitForIp --X:logFile=/tmp/ovftool.log --X:logLevel=verbose --X:logTransferHeaderData \'  >> ${MYSCRIPT}
echo '--name='${NAME}' --datastore='${DATASTORE}' --powerOn --noSSLVerify \'  >> ${MYSCRIPT}
echo '--diskMode=thin \'  >> ${MYSCRIPT}

SAVEIFS=$IFS
IFS=$(echo -en "\n\b")

networks=$(govc import.spec ${OVA} |jq .NetworkMapping[].Name)
#network=$(ovftool ${1} |grep Networks -A 3 |grep Name)

for NETWORK in ${networks}; do
    echo '--net:'${NETWORK}'="'${CPOD_PORTGROUP}'" \'  >> ${MYSCRIPT}
done

params=$(govc import.spec ${OVA} |jq .PropertyMapping[].Key)
#params=$(ovftool  ${1} |grep "Key:" |awk '{print $2}')
for PARAM in $params; do
	GUESS=$(guess_param ${PARAM})
    echo '--prop:'${PARAM}'='${GUESS}' \' >> ${MYSCRIPT}
done
IFS=$SAVEIFS

echo ${OVA}' \' >> ${MYSCRIPT}
echo "vi://${VCENTER_ADMIN}:${VCENTER_PASSWD}@${VCENTER}/${VCENTER_DATACENTER}/host/${VCENTER_CLUSTER}/Resources/cPod-Workload/${VAPP}"  >> ${MYSCRIPT}

#====
echo " "  >> ${MYSCRIPT}
echo "# =============================="  >> ${MYSCRIPT}
echo "# datastore=${VCENTER_DATASTORE}"  >> ${MYSCRIPT}
echo "# pwd=${PASSWORD}"  >> ${MYSCRIPT}
echo "# hostname=${HOSTNAME}.${DOMAIN}" >> ${MYSCRIPT}
echo "# domain=${DOMAIN}" >> ${MYSCRIPT}
echo "# ip=${IP}" >> ${MYSCRIPT}
echo "# netmask=255.255.255.0" >> ${MYSCRIPT}
echo "# gateway=${GATEWAY}" >> ${MYSCRIPT}
echo "# ntp=${GATEWAY}" >> ${MYSCRIPT}

vi ${MYSCRIPT}
echo
echo "Path to script : ${MYSCRIPT}"
echo "to deploy ova run : sh ${MYSCRIPT}"
