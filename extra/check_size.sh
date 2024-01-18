#!/bin/bash
#tonev@gmx.net


#govc device.info -vm /muc-dc01/vm/cPod-CPBU-V441-esx04
#govc ls /*/vm/*
#govc vm.info /muc-dc01/vm/cPod-CPBU-V441-esx04
#govc device.ls -vm /muc-dc01/vm/cPod-CPBU-V441-esx04
#govc datastore.disk.info 1280ce62-e49a-3a3f-d2f7-a4bf016abb56/cPod-CPBU-V441-esx04_6.vmdk

. ./env

[ "$1" == "" ] && 
echo "usage: ./extra/check_size.sh        <cpodname> |" &&
echo "                                    <list> [cpodname] |" && 
echo "                                    <all> | <fetch> | <vms-list> | <help> | <refresh> " &&
echo "" &&
echo "Shows the size of cpod, if cpodname is \"all\" lists all objects" &&    
echo "Try '$0 help' for more information." &&
exit 1
   
PASSWORD=$VCENTER_PASSWD
ESX_FQDN=""
TSM_SSH="false"
CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
LHEADER=$( echo ${HEADER} | tr '[:upper:]' '[:lower:]' )
NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
#PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} )
OUTPUT=$( echo "/tmp/vsan.out" | tr '[:upper:]' '[:lower:]')
VMS_OUTPUT=$( echo "/tmp/vms.out" | tr '[:upper:]' '[:lower:]')

#create dirty flag file for checking if cached files are outdated. it should be started when cpodctl creates pods or removes them
#if refresh-needed is newer than vsan.out get_objects has to run for cases : all,cpod-name, partly list 
DIRTY=$( echo "/tmp/refresh-needed")
#fill number of cpods in DIRTY. Will be used to check if changes are there
VMS=($(./compute/list_cpod.sh))
#number of seconds in a day
DAY=86400


#Functions start here
get_objects() {

                start=`date +%s`
		#fetch list with vsan objects size an mapping output in cache tmp folder
		echo ${ESX_FQDN}
		if [ "$1" == "ssh" ] ; then
			#get health status from vsan node
        		HEALTHY=$( sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} \
        		"esxcli vsan cluster get" 2>/dev/null | grep "Local Node Health State" | cut -d ' ' -f8 )
			if [ "${HEALTHY}" == "HEALTHY" ]; then
	                	echo "ESX: $ESX_FQDN is ${HEALTHY}, fetching object data via SSH"
			else
				echo "ESX: $ESX_FQDN is ${HEALTHY}. $(wc $OUTPUT) lines received via SSH. Hit enter or ctrl-c to abort:"
                		read answer
                		echo "Fetch was Aborted! but will use previous $OUTPUT data"
			fi

			#we assume the ssh root password is the same as vCenter Password
			PASSWORD=$VCENTER_PASSWD
			sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} \
			"esxcli vsan debug object list --max-number 20000 |  grep -e 'Group UUID:' -e 'Object UUID:' -e 'Size' -e ' Used:' -e ' Type:' -e 'Path:' | sed -e s/'Object UUID'/Object/ -e s/'Group UUID'/Group/ -e s/' GB'// -e s/'(Exists)'// -e s/' ('/'('/ -e  s/'[a-zA-Z0-9/:-]*\/'// | xargs -n 12" 2>/dev/null > ${OUTPUT} &
			echo "$OUTPUT created via SSH"
		else
			
			#alternative govc can be used to fetch the vsan objects. need to compare which is faster.
			GOVC_HOST=${ESX_FQDN}
			govc host.esxcli vsan debug object list -max-number 20000 | sed -e s/storageType:/storagetype:/ | grep -e 'GroupUUID:' -e 'ObjectUUID' -e 'Path:' -e 'Size' -e 'Type: ' -e 'Used: '  | sed -e s/'ObjectUUID:'/Object:/ -e s/'GroupUUID:'/Group:/ -e s/' GB'// -e s/'(Exists)'// -e s/' ('/'('/ -e  s/'[a-zA-Z0-9/:-]*\/'//  | xargs -n 12 | awk '{print $3,$4,$7,$8,$11,$12,$9,$10,$5,$6,$1,$2}' > ${OUTPUT} & 
			echo "$OUTPUT created via GOVC"
			GOVC_HOST=${VCENTER}
			
		fi

		while kill -0 $! 2>/dev/null; do
    			printf '.' > /dev/tty
    			sleep 1
		done
		end=`date +%s`
		echo Execution time was `expr $end - $start` seconds.

#		echo "Improoving output.."
#                sed -i 's/[a-zA-Z0-9/:-]*\///' $OUTPUT


#if [ "$DIRTY" -nt "$OUTPUT" ] ; then
#        echo "$DIRTY was modified. $OUTPUT needs refresh "

#else
#        echo "$OUTPUT may be outdated. Try $0 <refresh> to get latest object data"
#fi
}


#it will set the ESX_FQDN variable that is used from get_objects function
#ssh is not always on so here govc is used 
get_host() {

#export GOVC_HOST=${VCENTER}
HOSTS=($( govc ls host/$VCENTER_CLUSTER | cut -d '/' -f5 | tail -n +2 ))
[[ -z "${HOSTS}" ]] && { echo "Error: No Hosts are available check if your VC or cluster is set correctly." ;  exit 1; }

for FQDN in ${HOSTS[@]} 
do
	echo ${FQDN}
	GOVC_HOST=$FQDN
	STATE=$( govc host.info | grep "State:") 
	echo ${STATE}
	if [[ ${STATE} == *"connected"* ]]; then
		echo "It is connectable"
		TSM_SSH=$(govc host.service.ls -json | jq ' .[] | select(.Key=="TSM-SSH").Running ')
		echo "and SSH is $TSM_SSH"
		ESX_FQDN=$FQDN		
		export GOVC_HOST=${VCENTER}
		break
	else
		echo "it is not connectable"
	fi	
done

}


get_vms () {
	VMS=($(./compute/list_cpod.sh ))
	SIZE_TOTAL=0
for VM in ${VMS[@]}
do
	SIZE_VM=0
	echo "================"
	echo "VMs in cPOD: $VM"
	CONTENTS=($( govc ls /$GOVC_DATACENTER/vm | grep -i $VM ))
	for CONT in ${CONTENTS[@]}
	do
		SIZE_CONT=0
		DISKS=($( govc device.info -json -vm $CONT disk-* | jq .Devices[].CapacityInKB ))
		SIZE_CONT=$(IFS=+; echo "$((${DISKS[*]}))")
		#echo "$CONT : $SIZE_CONT with Disk ${DISKS[@]}"
		SIZE_VM=$(echo "$SIZE_VM + $SIZE_CONT" | bc)
	done
	SIZE_TOTAL=$(echo "$SIZE_TOTAL + $SIZE_VM"| bc)
	echo "Provisioned Size of $VM is $( echo "scale=2; $SIZE_VM / 1073741824" | bc -l) TB"
done
	echo "Provisioned Size of Total is $( echo "scale=2; $SIZE_TOTAL / 1073741824" | bc -l) TB"
}

get_vms_list () {

	VMS=($(./compute/list_cpod.sh | sed s/$LHEADER-//))
	[[  -f $DIRTY ]] && echo "${#VMS[@]}" > $DIRTY || echo "$DIRTY does not exist, creating it now"; touch $DIRTY ; echo "${#VMS[@]}" > $DIRTY
	echo -e "-----cPod-Name-----#SIZE TB\n" > $VMS_OUTPUT 
	#delete the old contents of the output. this script runs only if the refresh is needed, or number of cms increased
	echo "There are ${#VMS[@]} cPods to be processed"
	i=0
for VM in ${VMS[@]}
do
	i=$(expr $i + 1) ; echo -e "\r$i"; 
	SIZE_VM=0
	CONTENTS=($( govc ls /$GOVC_DATACENTER/vm | grep -i $VM ))
	for CONT in ${CONTENTS[@]}
	do
		SIZE_CONT=0
                DISKS=($( govc device.info -json -vm $CONT disk-* | jq .Devices[].CapacityInKB ))
                SIZE_CONT=$(IFS=+; echo "$((${DISKS[*]}))")
                #echo "$CONT : $SIZE_CONT with Disk ${DISKS[@]}"
                SIZE_VM=$(echo "$SIZE_VM + $SIZE_CONT" | bc)
	done	
	echo -e "$VM#$( echo "scale=2; $SIZE_VM / 1073741824" | bc -l) TB\n" >> $VMS_OUTPUT
done
	cat $VMS_OUTPUT | column -t -s '#' 
	
}
#Main function
if [  -f $DIRTY ]; then
        DUEDATE=$(( $(stat -c %Y $DIRTY)-$DAY ))
        echo "due date is $(date -d @$DUEDATE)"
        if [ $(cat $DIRTY) -ne ${#VMS[@]} ]; then
                echo "${#VMS[@]}" > $DIRTY
                echo "number of cpods changed. need refresh"
                #get esxi hosts from datacenter and if ssh service is on
                get_host
                #get vsan objects either via ssh or govc and input in $OUTPUT file
                [ $TSM_SSH == "true" ] && get_objects ssh || get_objects;
                #get vms provisioned space via govc and input in $VMS_OUTPUT
                get_vms_list
        else
                echo "number of cpods is unchanged. unsing $OUTPUT for vsan cpods and $VMS_OUTPUT for cpods on other datastores"
        fi
else
        echo "$DIRTY does not exist, creating it now"
        touch $DIRTY
        echo "${#VMS[@]}" > $DIRTY
fi

#Case choice starts here 
case "$1" in
all)
	namespace=$( echo "all")
	get_host
	[[ ! -f $OUTPUT ]] && get_objects ssh;
	[ "$DIRTY" -nt "$OUTPUT" ] && get_objects ssh;
 	echo "Calculating all cPods:"
	
	#calculate vms and namespace for all
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT ); echo -e "'$namespace' \t\t uses $( echo "scale=2; $used / 1024" | bc -l ) TB allocates $( echo "scale=2; $a / 1024" | bc -l ) TB"
	
	#calculate snapshots for all
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep "0000"); echo -e "snapshot \t uses $used GB allocates $a GB"
	exit 1
	;;

fetch)
	get_host
	echo "Fetching object data from '$ESX_FQDN' to '$OUTPUT'"
	get_objects  
	exit 1
	;;

vms)
	echo "getting VMs"
	get_vms 
	;;
vms-list)
	[[ ! -f $VMS_OUTPUT ]] && echo "output VMs in $VMS_OUTPUT" || echo "creating file $VMS_OUTPUT"; touch $VMS_OUTPUT
	
	get_vms_list &
	pid=$!
	s='-\|/'; i=0; while kill -0 $pid 2>/dev/null; do i=$(( (i+1) %4 )); printf "\r${s:$i:1}"; sleep .1; done
	;;
	
list)
	get_host
        [[ ! -f $OUTPUT ]] && get_objects ssh;
        [ "$DIRTY" -nt "$OUTPUT" ] && get_objects ssh;
	VSANCPODS=$( grep -o $HEADER-[a-zA-Z0-9]*-[a-zA-Z0-9]* $OUTPUT | sed -e s/$HEADER-// | sed -e s/'-esx[0-9]*'// -e s/'-vcsa'// -e s/'-cpodrouter'// -e s/'-forty'// |  sort -u )
              
	if [ "$2" == "" ]; then
	#no second parameter after <list>
  	echo "List all vSAN cPODs:"
	for CPOD in ${VSANCPODS} ; do
              	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $CPOD); echo -e " '$CPOD' \t uses $used GB allocates $a GB"
	done
	
	else
	#second parameter 	
	echo List VMs in $2
		NESTED=$( grep -o $2-[a-zA-Z0-9/]* $OUTPUT | sed -e s/$2-// | sort -u )
		for CPOD in ${NESTED} ; do 
			used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $2-$CPOD); echo -e " '$CPOD' \t uses $used GB allocates $a GB"

		done
	fi

	exit 1
	;;

refresh)
	touch $DIRTY
	exit 1
	;;

help)
	echo "usage:   $0   <cpodname> |  <all> | <help> " &&
	echo "              <list> [cpodname] | " &&
	echo "              <vms> | <fetch> | <refresh> |" &&
	echo "" &&
	echo "<all>            :  the vsan objects from first esxi " &&        
	echo "<list> [cpodname]: lists all objects in the cache file '/tmp/vsan.out' OR '/tmp/vsan.out-cpodname'" &&        
	echo "<cpodname>       : calculates only the root objects of this cpod. only high level objects (ESXi VMs, cpodrouter)" &&         
	echo "<refresh>        : same as 'touch /tmp/refresh-needed' . triggers object refresh in '/tmp/vsan-out' " &&	
	echo "<vms-list>       : get vm-list and size from govc instead vsan" &&
	echo "<fetch>          : fetch via SSH the vsan object data from first ESXi in the hosts file" &&
	echo "<help>           : this page" 
	echo "" &&	
	echo "vSAN capacity properties:" &&
	echo "\"Used\"  : This is the physical space, the total sum of objects placed on storage. It includes the storage policy overhead and the small object overheads" && 
	echo "\"Size\"  : The size of the virtual object. It is the virtually allocated space in GB without the policy overhead. This can be bigger than Used because some objects are thin provisioned. Namespace objects are max 255GB of size and are thin-provisioned. The metric \"Provisioned Space\" in VC is about the double ot \"Size\" with RAID1 policy." &&     
	exit 1
	;;
 
*)
	namespace=$( echo ${CPOD_NAME})
	get_host
	#this version fetches vsan objects from the first level nested VM level
	[ ! -f $OUTPUT ] && echo "$OUTPUT does not exist"
       	[ "$DIRTY" -nt "$OUTPUT" ] && get_objects ssh;
 	echo "Calculating cPod size:"

	#calculate vms and snapshots for namespace
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace); echo -e "'$namespace' \t uses $used GB allocates $a GB"

	#snapshots
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace | grep "0000"); echo -e "snapshot \t uses $used GB allocates $a GB"
	;;

esac


 
