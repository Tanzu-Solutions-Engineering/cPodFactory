#!/bin/bash
#bdereims@vmware.com

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod> <#_of_esx>" && exit 1 

HOSTS=/etc/hosts
GEN_PASSWD=$( ./extra/passwd_for_cpod.sh ${1} )

main() {
	echo "=== Preparing cPod '${1}' with ${2} ESX."

	SHELL_SCRIPT=prep_and_add_esx.sh

	SCRIPT_DIR=/tmp/scripts
	SCRIPT=/tmp/scripts/$$

	mkdir -p ${SCRIPT_DIR} 
	cp ${COMPUTE_DIR}/${SHELL_SCRIPT} ${SCRIPT}
	sed -i -e "s/###ROOT_PASSWD###/${ROOT_PASSWD}/" -e "s/###GEN_PASSWD###/${GEN_PASSWD}/" \
	-e "s/###ISO_BANK_SERVER###/${ISO_BANK_SERVER}/" \
	-e "s!###ISO_BANK_DIR###!${ISO_BANK_DIR}!" \
	-e "s/###NUM_ESX###/${2}/" \
	-e "s/###NOCUSTO###/${NOCUSTO}/" \
	${SCRIPT}

	CPOD_NAME="cpod-$1"
	CPOD_NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )

	./compute/wait_ip.sh ${CPOD_NAME_LOWER} 
	sleep 20
	
	THEIP=$( cat /etc/hosts | awk '{print $1,$2}' | sed -n "/${CPOD_NAME_LOWER}$/p" | awk '{print $1}' )

        sshpass -p ${ROOT_PASSWD} scp ~/.ssh/id_rsa.pub root@${THEIP}:/root/.ssh/authorized_keys 2>&1 > /dev/null
        scp -o StrictHostKeyChecking=no ${SCRIPT} root@${THEIP}:./${SHELL_SCRIPT} 2>&1 > /dev/null
        ssh -o StrictHostKeyChecking=no root@${THEIP} "./${SHELL_SCRIPT}" 2>&1 > /dev/null

	#rm ${SCRIPT}
}

main $1 $2
