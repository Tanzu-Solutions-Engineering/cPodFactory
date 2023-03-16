#/bin/sh
#bdereims@vmware.com

# Tag all disk unles T0 as SSD
for DISK in $( esxcli storage core device list | grep mpx | sed -e "/^.*D/d" -e "/T0/d" );
do 
	echo ${DISK}
	esxcli storage hpp device set -d ${DISK} -M true
#	esxcli storage nmp satp rule add -s VMW_SATP_LOCAL -d ${DISK} -o enable_ssd
	esxcli storage hpp device set -d ${DISK} -M true
	esxcli storage core claiming reclaim -d ${DISK}
done
esxcli storage hpp device usermarkedssd list
