#/bin/sh

if [ "${1}" == "" ]; then
	echo "Rien à mettre en production!"
	echo "### ${1}" >> ./log
	exit 0
fi

echo "Lancement de la mise en production de ${1} ${2} ${3}"
./trigger_pipeline_saas.sh ${1}
