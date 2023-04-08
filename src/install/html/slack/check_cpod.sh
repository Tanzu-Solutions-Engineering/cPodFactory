#/bin/sh

NAME=$( echo $1 | tr '[:upper:]' '[:lower:]' )
if [ "x${NAME}" != "x" ]; then 
	RESULT=$( cat /etc/hosts | awk '{print $2"#"}' | grep "cpod-${NAME}#" | wc -l )
	RESULT=$( expr ${RESULT} )
	if  [ ${RESULT} -gt 0 ]; then
		echo "No Ok!"
		exit 1
	fi
fi

echo "Ok!"
exit 0
