#/bin/bash

STATUS=1
ITERATE=30
	
printf "Waiting for ${1} "
while [ ${STATUS} -gt 0 ] && [ ${ITERATE} -gt 0 ]
do
	STATUS=$( ping -c 1 ${1} 2>&1 > /dev/null ; echo $? )
	STATUS=$(expr $STATUS)
	ITERATE=$( expr ${ITERATE} - 1 )
	printf "."
done

printf "\n"

if [ ${ITERATE} -le 0 ]; then 
	echo "${1} is unreachable"
	exit 1
fi

echo "${1} is reachable"
