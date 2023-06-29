#!/bin/bash
#tonev@gmx.net

# $1 : Name of cPod with cloudbuilder deployed

source ./env
source ./govc_env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod>"  && echo "usage example: $0 VCF45 " && exit 1

START=$( date +%s )

FinalIsoFileName="/mnt/iso/sddc-foundation-bundle-"
cbDomain=$(cat /etc/dnsmasq.conf | grep -Eo 'domain=[^+]*$'  | sed  s/domain=//)
url="cloudbuilder.cpod-$1.$cbDomain"
#downloading the iso called VMware-VMvisor-Installer-7.0U3g-20328353.x86_64.iso  . from directory /mnt/iso/sddc-foundation-bundle-4.5.0.0-20612863/esx_iso

CHECK=$( sshpass -p $( ./extra/passwd_for_cpod.sh $1 ) ssh -o StrictHostKeyChecking=no root@${url} \
        "ls $FinalIsoFileName*/esx_iso/VMware-VMvisor*" 2>/dev/null )
if [ "$( echo $CHECK | grep -o sshpass | sort -u )" == "sshpass"  ]; then
                echo "Failed fetching object data via SSH"
	else 
		echo
		echo "============================================"
		echo "downloading $ISO_BANK_DIR/$( echo $CHECK | sed 's/.*\///' ) file from Cloud Builder $url"
		echo "============================================"
	fi

#echo "Download iso with SCP
sshpass -p $( ./extra/passwd_for_cpod.sh $1 ) scp root@$url:$FinalIsoFileName*/esx_iso/VMware-VMvisor* $ISO_BANK_DIR

echo "========================================="
echo "=== fetch via SCP is finished ==="
END=$( date +%s )
TIME=$( expr ${END} - ${START} )
echo "=== In ${TIME} Seconds ==="
echo "========================================="

