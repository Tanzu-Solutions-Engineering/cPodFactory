#!/bin/bash
#bdereims@vmware.com

# $1 from
# $2 to

. ./env
CPOD="CDAY"
. ./${COMPUTE_DIR}/cpod-xxx_env


### Local vars ####

OVA=${OVA_PHOTONOS}
TARGET=vcsa.${DOMAIN}/cPod-${CPOD}/host/Cluster

###################

deploy_photonos() {
	echo "Deploying ${NAME}..."

export MYSCRIPT=/tmp/$$-${1}

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --powerOffTarget --allowExtraConfig \
--X:apiVersion=5.5 --diskMode=thin --powerOn \
"--datastore=${DATASTORE}" -n=${NAME} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

	nohup sh ${MYSCRIPT} >/dev/null 2>&1 & 
}

for i in `seq ${1} ${2}`;
do
	NUM=$( printf %02d ${i} )
	HOSTNAME="${HOSTNAME_PHOTONOS}-${NUM}"
	NAME="${NAME_PHOTONOS}-${NUM}"

	deploy_photonos ${NUM}
done 

exit 0

export MYSCRIPT=/tmp/$$

cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --powerOffTarget --allowExtraConfig \
--X:apiVersion=5.5 --diskMode=thin \
"--datastore=${DATASTORE}" -n=${NAME} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

sh ${MYSCRIPT}

rm ${MYSCRIPT}
