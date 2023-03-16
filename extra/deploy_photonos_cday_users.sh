#!/bin/bash
#bdereims@vmware.com

. ./env
CPOD="CDAY"
. ./${COMPUTE_DIR}/cpod-xxx_env


### Local vars ####

OVA=${OVA_PHOTONOS}
TARGET=vcsa.${DOMAIN}/cPod-${CPOD}/host/Cluster

###################

deploy_photonos() {
	echo "Deploying ${1}..."

	export MYSCRIPT=/tmp/$$-${1}

	cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --powerOffTarget --allowExtraConfig \
--X:apiVersion=5.5 --diskMode=thin --powerOn \
"--datastore=${DATASTORE}" -n=${1} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

	nohup sh ${MYSCRIPT} >/dev/null 2>&1 & 
}

deploy_photonos_pcli() {
	echo "deploying ${1}..."
	./extra/deploy_photonos_cday_pcli.sh ${1}
}

for i in `cd ~ ; ./list_mail_users.sh | sed -e 's/@.*$//'`;
do
	NAME="${i}"
	#deploy_photonos ${NAME}
	deploy_photonos_pcli ${NAME}
done 

exit 0
