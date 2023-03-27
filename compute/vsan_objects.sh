#!/bin/bash
#vtonev@vmware.com

# $1 : cPod Name

. ./env

[ "$1" == "" ] && echo "usage: $0 <name_of_cpod | all | list>  show size of cpod, if name is all lists all objects" &&    echo "<all> : reads the vsan objects from first esxi " &&        echo "<list> <cpodname>: lists all objects in the cache file /tmp/vsan.out-all | /tmp/vsan.out-cpodname" &&        echo "<name_of_cpod> caches only the objects of this cpod. current version caches only high level objects (not from the nested environment)" &&         echo "<touch> same as touch /tmp/refresh-needed" &&	echo "" &&	echo "Note: the scipt needs file in /tmp/refresh-needed. you can create it with touch /tmp/refresh-neeed or touch command"  &&  echo "Used: This is the physical space, the total sum of objects placed on storage. It includes the storage policy overhead and the small object overheads" && echo "Size: The size of the virtual object. It is the virtually allocated space in GB without the poliy overhead. This can be bigger than Used because some objects are thin provisioned. Namespace objects are always max 255GB of size and are thin-provisioned. The metric \"Provisioned Space\" in VC is about the double ot \"Size\" with RAID1 policy." &&     exit 1
   

get_objects() {

echo "The FQDN from the first ESX is $ESX_FQDN"
echo "get objects from ESX cmmds $NAME_LOWER $PASSWORD"

if [ "$DIRTY" -nt "$OUTPUT" ] ; then
        echo "$OUTPUT needs refresh, because touch $DIRTY was used"
        #get health status from vsan node
        HEALTHY=$( sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "esxcli vsan cluster get" | grep "Local Node Health State" | cut -d ' ' -f8 )

        if [ "${HEALTHY}" == "HEALTHY" ]; then
                echo "ESX is healthy, fetching data via SSH"
                #fetch list with vsan objects size an mapping output in cache tmp folder
                sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "esxcli vsan debug object list --all |  grep -e 'Object UUID' -e 'Size' -e 'Used:' -e 'Group UUID:' -e 'Type:' -e 'Path:' | sed -e s/' UUID'// -e s/' GB'// -e s/'(Exists)'// -e s/' ('/'('/ | xargs -n 12" > ${OUTPUT}

                #post processing output here (it is much faster to do here) cleans the output for later manipulation
                #this line removes the unnecessary path from the objects, gets only the vmdk names and namespaces
                sed -i 's/[a-zA-Z0-9/:-]*\///' $OUTPUT

                #Test only: copy script file to esxi
                #sshpass -p ${PASSWORD} scp -o StrictHostKeyChecking=no /tmp/script.sh root@${ESX_FQDN}:/tmp/script.sh
                #create permissions and output file with script
                #sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "chmod 770 /tmp/script.sh"
                #sshpass -p ${PASSWORD} ssh -o StrictHostKeyChecking=no root@${ESX_FQDN} "/tmp/script.sh" > ./${CPOD_NAME}.obj

                #gets Objects for the selected cPOD Namespace in a list of objects
                #cat ${CPOD-NAME}.obj | grep ${HEADER}-${CPOD_NAME}

        else
                echo "ESX not reached via SSH. Hit enter or ctrl-c to abort:"
                read answer
                echo "Aborted!"
        fi


else
        echo "$OUTPUT is actual, because $DIRTY was not modified. Try touch $DIRTY to force refresh"
        #post processing output here (it is much faster to do here) cleans the output for later manipulation
        #test: Manipulation to extract the Type of object (vdisk namespace or vmswap
        #cat /tmp/vsan.out-all | grep -o "Type: [a-z]* " | cut -d " " -f 2

fi

        #shows the used and allocated storage for a namespace obj
#        used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace); echo "$namespace uses $used GB allocates $a GB"

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
#touch echo $DIRTY
 
case "$1" in
all)
	namespace=$( echo "all")
	get_objects
	;;
list)
	

	OUTPUT=$( echo "/tmp/vsan.out" | tr '[:upper:]' '[:lower:]' )
	echo "cat $OUTPUT | grep $2"
	[ "$2" != "" ] && cat $OUTPUT | grep $2
	exit 1
	;;
touch)
	touch echo $DIRTY
	exit 1
	;;
*)

#	Uncoment if more detailed obj file is needed. can go to nested esxi for more detail objects, snapshots, vms.
#	ESX=$( ssh ${NAME_LOWER} "cat /etc/hosts | cut -f2 | grep esx | tail -1" )

#	ESX_FQDN="${ESX}.${NAME_LOWER}.${ROOT_DOMAIN}"
	#first version fetches vsan objects from physical level
	get_objects
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace); echo "$namespace uses $used GB allocates $a GB"
	#snapshots
	used=0; a=0; while read -a vms ; do used=$( echo "$used + ${vms[5]}" | bc ); a=$( echo "$a + ${vms[3]}" | bc); done < <(cat $OUTPUT | grep $namespace | grep "0000"); echo "Snapshot of $namespace uses $used GB allocates $a GB"
	;;
esac

