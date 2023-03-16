#!/bin/bash
#bdereims@vmware.com

N=5
HEADER="SMOKETEST"

for i in $( seq -f "%03g" 1 ${N} );
do
	NUM_ESX=$( echo $RANDOM % 6 + 3 | bc )

	case "$1" in
		create)
			echo ">>> Create #${i} with ${NUM_ESX} ESXi"
			./create_cpod.sh ${HEADER}${i} ${NUM_ESX} smoketester &
			;;
		
		delete)
			echo ">>> Delete #${i}"
			./delete_cpod.sh ${HEADER}${i} smoketester & 
			;;
         
		*)
			echo $"Usage: $0 {create|delete}"
			exit 1
 
	esac
done 		
