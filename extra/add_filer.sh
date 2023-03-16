#5!/bin/bash
#bdereims@vmware.com

# Usage : ./add_filer.sh EUC (not cPod-EUC)

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod> <owner's email alias (ex: bdereims)>" && exit 1 

if [ "${2}" ==  "" ]; then
	OWNER="admin"
else
	OWNER="${2}"
fi

#========================================================================================

DNSMASQ=/etc/dnsmasq.conf
HOSTS=/etc/hosts

portgroup() {
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
	
	PORTGROUP_NAME=${CPOD_PORTGROUP}
}

deploy_filer() {
	NAME_UPPER=$( echo ${NAME_LOWER} | tr '[:lower:]' '[:upper:]' )
	${COMPUTE_DIR}/deploy_filer.sh ${NAME_UPPER} ${PORTGROUP_NAME} ${ROOT_DOMAIN}
}

exit_gate() {
	#[ -f lock ] && rm lock
	exit $1 
}

check_space() {
	#./${EXTRA_DIR}/check_space.sh 2>&1 > /dev/null
	if [ $? != 0 ]; then
		echo "Error: No more space, can't continue."
		./${EXTRA_DIR}/post_slack.sh ":thumbsdown: Can't create cPod *${1}*, no more space on Datastore."
		exit_gate 1
	fi
}

check_if_existing() {
	IN_HOSTS=$( grep ${1} ${HOST} | wc -l )	
	IN_DNSMASQ=$( grep ${1} ${DNSMASQ} | wc -l )	
	RESULT=$( expr ${IN_HOSTS} + ${IN_DNSMASQ} )

	if [ ${RESULT} > 0 ]; then
		NAME_UPPER=$( echo $1 | tr '[:lower:]' '[:upper:]' )
		echo "=== cPod ${NAME_UPPER} already exists, choose other name or destroy it."
		./${EXTRA_DIR}/post_slack.sh ":thumbsdown: cPod *${NAME_UPPER}* already exists."
		exit 1
	fi
}

passwd() {
	CPOD_PASSWD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${NAME_LOWER} )
}

filerip() {
	FILER_IP=$( ${COMPUTE_DIR}/cpod_ip.sh ${NAME_LOWER} )		
	FILER_IP="${FILER_IP}.2"
}

main() {
	CPOD_NAME="cpod-$1"
	NAME_HIGHER=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
	CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
	LINE=$( sed -n "/${CPOD_NAME_LOWER}\t/p" /etc/hosts | cut -f3 | sed "s/#//" | head -1 )
	if [ "${LINE}" != "" ] && [ "${LINE}" != "${2}" ]; then
        	echo "Error: You're not allowed to deploy"
        	./${EXTRA_DIR}/post_slack.sh ":wow: *${2}* you're not allowed to deploy in *${NAME_HIGHER}*"
        	exit 1
	fi

	IP=$( ./compute/cpod_ip.sh ${1} )
	IP="${IP}.2"
	STATUS=$( ping -c 2 ${IP} 2>&1 > /dev/null ; echo $? )
	STATUS=$(expr $STATUS)
	if [ ${STATUS} == 0 ]; then
        	echo "Error: Something has the same IP."
        	./${EXTRA_DIR}/post_slack.sh ":wow: Are you sure that cPodFiler is not already deployed in *${1}*. Something have the same @IP."
        	exit 1
	fi

	NAME_LOWER=$( echo $1 | tr '[:upper:]' '[:lower:]' )

	check_space $1

	echo "=== Deploying filer in '${HEADER}-${1}'."
	./${EXTRA_DIR}/post_slack.sh "Starting deploying filer in cPod *${1}*"
	START=$( date +%s ) 

	portgroup

	echo "Portgroup : ${PORTGROUP_NAME}"

	deploy_filer 
	
	echo "=== Deployment is finished."
	END=$( date +%s )
	TIME=$( expr ${END} - ${START} )
	echo "In ${TIME} Seconds."
	./${EXTRA_DIR}/post_slack.sh ":thumbsup: cPod *${1}* has been successfully created in *${TIME}s*"

	exit_gate 0
}

main $1 $2
