#!/bin/bash
#vtonev@vmware.com

# $1 : cPod Name
. ./env

[ "$1" == "" ] && 
echo "usage: ./compute/vsan_objects.sh    <cpodname> |" &&
echo "                                    <list> [cpodname] |" && 
echo "                                    <all> | <fetch> | <help> | <refresh> " &&
echo "" &&
echo "Shows the size of cpod, if name is <all> lists all objects" &&    
echo "Try '$0 help' for more information." &&
exit 1
   

get_objects() {


if [ "$DIRTY" -nt "$OUTPUT" ] ; then
        echo "Check: $DIRTY was modified and $OUTPUT needs refresh"
        #get health status from vsan node
        HEALTHY=$( sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} \
	"esxcli vsan cluster get" 2>/dev/null | grep "Local Node Health State" | cut -d ' ' -f8 )
	
        if [ "${HEALTHY}" == "HEALTHY" ]; then
                echo "ESX: $ESX_FQDN is ${HEALTHY}, fetching object data via SSH"
                
		#fetch list with vsan objects size an mapping output in cache tmp folder
                sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} \
		"esxcli vsan debug object list --all |  grep -e 'Object UUID' -e 'Size' -e 'Used:' -e 'Group UUID:' -e 'Type:' -e 'Path:' | sed -e s/' UUID'// -e s/' GB'// -e s/'(Exists)'// -e s/' ('/'('/ | xargs -n 12" 2>/dev/null > ${OUTPUT} &
		echo "$OUTPUT created"
		
		while kill -0 $! 2>/dev/null; do
    			printf '.' > /dev/tty
    			sleep 1
		done
		echo

                #post processing output here (it is much faster to do here) cleans the output for later manipulation
                #this line removes the unnecessary path from the objects, gets only the vmdk names and namespaces
		echo "Improoving output.."
                sed -i 's/[a-zA-Z0-9/:-]*\///' $OUTPUT

                #Test only: copy script file to esxi
                #sshpass -p ${PASSWORD} scp -o StrictHostKeyChecking=no /tmp/script.sh root@${ESX_FQDN}:/tmp/script.sh
                #create permissions and output file with script
                #sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "chmod 770 /tmp/script.sh"
                #sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "/tmp/script.sh" > ./${CPOD_NAME}.obj

                #gets Objects for the selected cPOD Namespace in a list of objects
                #cat ${CPOD-NAME}.obj | grep ${HEADER}-${CPOD_NAME}

        else
                echo "ESX: $ESX_FQDN is ${HEALTHY}. $(wc $OUTPUT) lines received via SSH. Hit enter or ctrl-c to abort:"
                read answer
                echo "Fetch was Aborted! but will use previous $OUTPUT data"
        fi


else
        echo "old $OUTPUT was used, because $DIRTY is unchanged. Try $0 <refresh> to get latest object data"
        #post processing output here (it is much faster to do here) cleans the output for later manipulation
        #test: Manipulation to extract the Type of object (vdisk namespace or vmswap
        #cat /tmp/vsan.out-all | grep -o "Type: [a-z]* " | cut -d " " -f 2

fi


}


CPOD_NAME=$( echo ${1} | tr '[:lower:]' '[:upper:]' )
NAME_LOWER=$( echo ${CPOD_NAME} | tr '[:upper:]' '[:lower:]' )
#PASSWORD=$( ${EXTRA_DIR}/passwd_for_cpod.sh ${CPOD_NAME} )
OUTPUT=$( echo "/tmp/vsan.out" | tr '[:upper:]' '[:lower:]')
namespace=$( echo ${CPOD_NAME})
PASSWORD=$VCENTER_PASSWD
ESX=$( cat /etc/hosts | cut -f2 | grep esx | head -1 )
ESX_FQDN="${ESX}.${ROOT_DOMAIN}"

#create dirty flag file for checking if cached files are outdated. it should be started when cpodctl creates pods or removes them
DIRTY=$( echo "/tmp/refresh-needed")
 
case "$1" in
all)
	namespace=$( echo "all")
	get_objects
	echo "Calculating size of objects for '$NAME_LOWER' cPod"
	
	#calculate vms and namespace for all
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT ); echo "'$namespace' uses $( echo "scale=2; $used / 1024" | bc -l ) TB allocates $( echo "scale=2; $a / 1024" | bc -l ) TB"
	
	#calculate snapshots for all
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep "0000"); echo "snapshot uses $used GB allocates $a GB"
	exit 1
	;;

fetch)
	echo "Fetching object data from '$ESX' to '$OUTPUT'"
	get_objects
	exit 1
	;;

list)
	OUTPUT=$( echo "/tmp/vsan.out" | tr '[:upper:]' '[:lower:]' )
	echo "cat $OUTPUT | grep $2"
	grep -o $HEADER-[a-zA-Z0-9]*-[a-zA-Z0-9]* $OUTPUT | sort -u
	[ "$2" != "" ] && cat $OUTPUT | grep $HEADER- | cut -d ' ' -f5,6,10
	exit 1
	;;

refresh)
	touch echo $DIRTY
	exit 1
	;;

help)
	echo "usage:   $0   <cpodname> | <list> | <all> | <help> ..." &&
	echo "" &&
	echo "<all>            : reads the vsan objects from first esxi " &&        
	echo "<list> <cpodname>: lists all objects in the cache file '/tmp/vsan.out' OR '/tmp/vsan.out-cpodname'" &&        
	echo "<cpodname>       : calculates only the root objects of this cpod. only high level objects (ESXi VMs, cpodrouter)" &&         
	echo "<refresh>        : same as 'touch /tmp/refresh-needed' . triggers object refresh in '/tmp/vsan-out' " &&	
	echo "<fetch>          : fetch via SSH the vsan object data from first ESXi in the hosts file" &&
	echo "" &&	
	echo "vSAN capacity properties:" &&
	echo "\"Used\"  : This is the physical space, the total sum of objects placed on storage. It includes the storage policy overhead and the small object overheads" && 
	echo "\"Size\"  : The size of the virtual object. It is the virtually allocated space in GB without the policy overhead. This can be bigger than Used because some objects are thin provisioned. Namespace objects are max 255GB of size and are thin-provisioned. The metric \"Provisioned Space\" in VC is about the double ot \"Size\" with RAID1 policy." &&     
	exit 1
	;;
 
*)
	#this version fetches vsan objects from the first level nested VM level
	get_objects
	echo "Calculating size of objects for '$NAME_LOWER' cPod"

	#calculate vms and snapshots for namespace
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace); echo "'$namespace' uses $used GB allocates $a GB"

	#snapshots
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace | grep "0000"); echo "snapshot uses $used GB allocates $a GB"
	;;


esac

