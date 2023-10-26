#!/bin/bash
#edewitte@vmware.com

# $1 : Name of template to create
# $2 : Path to ISO file
# $3 : cpod network name to use temporarily

source ./env
source ./govc_env


collect_info(){

    ISOSLIST=$(ls /data/BITS/VMware-VMvisor-Installer* | sed 's/.*\///')
    ISOSLIST=${ISOSLIST}" Quit"

    select ISO in ${ISOSLIST}; do 
        if [ "${ISO}" = "Quit" ]; then 
            exit
        fi
        echo "you selected ISO : ${ISO}"
        LongIsoFileName=$(ls /data/BITS/VMware-VMvisor-Installer* |grep ${ISO})
        shortIsoFileName="${ISO}"
        break
    done
    ISONAMECODE=$(echo ${ISO} |sed 's/VMware-VMvisor-Installer-//' | sed 's/.x86_64.iso//')
    TEMPLATENAME="template-ESX-${ISONAMECODE}"
    PORTGROUP="cpod-services"
}

START=$( date +%s ) 

if [ "$1" == "" -o "$2" == "" -o "$3" == "" ];
then
    echo "usage: $0 <name_of_template> <name_of_ISO_file> <temp_cpod_network>"
    echo "usage example: $0 template-ESX70u3f /data/nfs/ISO/VMware-VMvisor-Installer-7.0U3f-20036589.x86_64.iso cpod-services"
    collect_info
else
    TEMPLATENAME="${1}"
    LongIsoFileName="${2}"
    shortIsoFileName=$(echo "${LongIsoFileName}" | sed 's/.*\///')
    PORTGROUP=${3}
fi

FinalIsoFileName="ks-${shortIsoFileName}"
echo $TEMPLATENAME
echo $shortIsoFileName
echo $PORTGROUP

#Checks before execution
test_vm=$(govc find . -type m -name "${TEMPLATENAME}")

if [ "${test_vm}" != "" ];
then
    echo "${TEMPLATENAME} already present."
    echo "delete or rename it before creating a new one"
    exit
fi  

test_network=$(govc ls network |grep "cpod-services")

if [ "${test_network}" == "" ];
then
    echo "cpod-services not present."
    echo "check your setup."
    exit
fi

if [ ! -f "${LongIsoFileName}" ];
then
    echo "${LongIsoFileName} not found."
    echo "check file path."
    exit
fi

# Create template
echo "scp ${LongIsoFileName} root@forty-two:/tmp/cpod-template"

#using vm forty-two to generate iso file
echo
echo "============================================"
echo "generating ESXi iso file with kickstart file"
echo "============================================"

scp ${LongIsoFileName} root@forty-two:/tmp/cpod-template
scp ./extra/create_new_template_ks.cfg root@forty-two:/tmp/cpod-template/ks.cfg
ssh root@forty-two "./esxi_ks_iso.sh -i /tmp/cpod-template/${shortIsoFileName} -k /tmp/cpod-template/ks.cfg -w /tmp/cpod-template"
scp root@forty-two:/tmp/cpod-template/esxi-ks.iso ${CPODEDGE_DATASTORE}/${FinalIsoFileName}
#ssh root@forty-two "rm /tmp/cpod-template/*"

if [[ $GOVC_ISO_TRANSFER_REQUIRED == "yes" ]]; then
  echo "govc datastore.upload -ds=${GOVC_ISO_DATASTORE} ${CPODEDGE_DATASTORE}/${FinalIsoFileName} ${GOVC_ISO_FOLDER}/${FinalIsoFileName} "
  govc datastore.upload -ds=${GOVC_ISO_DATASTORE} ${CPODEDGE_DATASTORE}/${FinalIsoFileName} ${GOVC_ISO_FOLDER}/${FinalIsoFileName} 
fi

###
# generating powercli script to create template

echo
echo "========================================="
echo "generating ESXi template vm with powercli"
echo "========================================="

PS_SCRIPT=create_new_template.ps1

SCRIPT_DIR=/tmp/scripts
SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}


isofile="[${GOVC_ISO_DATASTORE}] ${GOVC_ISO_FOLDER}/ks-${shortIsoFileName}"


sed -i -e "s/###VCENTER###/${VCENTER}/" ${SCRIPT}
sed -i -e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" ${SCRIPT}
sed -i -e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" ${SCRIPT}
sed -i -e "s=###ISO_FILE###=${isofile}=" ${SCRIPT}
sed -i -e "s/###TEMPLATE_NAME###/${TEMPLATENAME}/" ${SCRIPT}
sed -i -e "s/###PORTGROUP###/${PORTGROUP}/" ${SCRIPT}
sed -i -e "s/###FOLDERNAME###/${TEMPLATE_FOLDER}/" ${SCRIPT}
sed -i -e "s/###RESOURCEPOOLNAME###/${TEMPLATE_RESOURCEPOOL}/" ${SCRIPT}
sed -i -e "s/###DATASTORE###/${DATASTORE}/" ${SCRIPT}


echo "Creating new template '${TEMPLATENAME}'"
echo ${SCRIPT}

docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT}

echo Waiting for template VM to be created

sleep 5


#while true; do
#    echo Checking template vm started
#    TEMPLATE_VM=$(govc vm.info ${TEMPLATENAME} | grep -i "poweredon" | wc -l)
#    if [ ${TEMPLATE_VM} -eq 1 ]; then
#        IP=$(govc vm.info -r ${TEMPLATENAME} | grep -i "ip" | awk '{print $3}')
#        echo Template IP : ${IP}
#        test=$(curl -s -k https://${IP})
#        if [ $? -eq 0 ]
#        then
#            echo "Template VM is up and running"
#            break
#        else
#            echo "Waiting for UI to start"
#        fi
#    else
#        echo Waiting for IP address for ${TEMPLATENAME}
#    fi
#    sleep 30
#done
#sleep 30

#
echo
ONCE=0
STATUS=""
PREVIOUSSTAGE=""
POWERSTATUS=""
printf "Checking template vm status"
while [ "${STATUS}" != "READY" ]
do
    POWERSTATUS=$(govc vm.info ${TEMPLATENAME} | grep -i "poweredon" | wc -l)
    if [ "${POWERSTATUS}" != "" ];
    then
        STATUS="POWEREDON"
        STAGE="Waiting for Template IP"
        IP=$(govc vm.info -r ${TEMPLATENAME} | grep -i "ip" | awk '{print $3}')
        if [ "${IP}" != "" ];
        then
            STAGE="Got IP : ${IP}. Waiting for UI to start"
            test=$(curl -s -k https://${IP})
            if [ $? -eq 0 ]
            then
                STAGE="Template VM is up and running"
                STATUS="READY"
            fi
        fi
    fi
	if [ "${STAGE}" != "${PREVIOUSSTAGE}" ]; then
		printf "\n\t %s" "${STAGE}"
		PREVIOUSSTAGE=${STAGE}
	fi
    printf '.' >/dev/tty
	sleep 5
done	
echo

#

echo finalising configuration of ${TEMPLATENAME}

PASSWORD=VMware1!

#remove uuid
sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "esxcli system settings advanced set -o /Net/FollowHardwareMac -i 1"
#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "cat /etc/vmware/esx.conf"
#sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "cp /etc/vmware/esx.conf /etc/vmware/esx.conf.bak"
sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "sed -i '/uuid/d' /etc/vmware/esx.conf"
#echo "pause" && read
sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "cat /etc/vmware/esx.conf"
#echo "pause" && read
sshpass -p ${PASSWORD} scp ./install/nested-esx/local.sh root@${IP}:/etc/rc.local.d/local.sh
#echo "pause" && read
sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${IP} "cat /etc/rc.local.d/local.sh"
#echo "pause" && read



#remove cd-rom
PS_SCRIPT=create_new_template_remove_cdrom.ps1

SCRIPT=/tmp/scripts/$$.ps1

mkdir -p ${SCRIPT_DIR}
cp ${EXTRA_DIR}/${PS_SCRIPT} ${SCRIPT}

sed -i -e "s/###VCENTER###/${VCENTER}/" ${SCRIPT}
sed -i -e "s/###VCENTER_ADMIN###/${VCENTER_ADMIN}/" ${SCRIPT}
sed -i -e "s/###VCENTER_PASSWD###/${VCENTER_PASSWD}/" ${SCRIPT}
sed -i -e "s/###TEMPLATE_NAME###/${TEMPLATENAME}/" ${SCRIPT}

echo "Removing cdrom from '${TEMPLATENAME}'"
echo ${SCRIPT}

#docker run --rm --it --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT} #2>&1 > /dev/null
docker run --interactive --tty --dns=${DNS} --entrypoint="/usr/bin/pwsh" -v /tmp/scripts:/tmp/scripts vmware/powerclicore:12.4 ${SCRIPT} #2>&1 > /dev/null

#govc remove cd-rom

#govc change network

govc vm.network.change -vm /intel-DC/vm/Templates/testme -net Dummy ethernet-0
govc vm.network.change -vm /intel-DC/vm/Templates/testme -net Dummy ethernet-1

#rm -fr ${SCRIPT}
echo
echo "========================================="
echo "=== New template Creation is finished ==="
END=$( date +%s )
TIME=$( expr ${END} - ${START} )
echo "=== In ${TIME} Seconds ==="
echo "========================================="
