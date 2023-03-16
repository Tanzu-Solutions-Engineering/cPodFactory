#!/bin/bash
#bdereims@vmware.com

# $1 from
# $2 to

. ./env
CPOD="CDAY"
. ./${COMPUTE_DIR}/cpod-xxx_env


### Local vars ####

#OVA=${OVA_PHOTONOS}
OVA=${BITS}/photonos-cday.ova
TARGET=vcsa.${DOMAIN}/cPod-${CPOD}/vm/PhotonOS

###################

deploy_photonos() {
	echo "Deploying ${1}..."

export MYSCRIPT=/tmp/$$-${1}

	cat << EOF > ${MYSCRIPT}
cd ${OVFDIR}
ovftool --acceptAllEulas --noSSLVerify --skipManifestCheck \
--X:injectOvfEnv --overwrite --allowExtraConfig \
--X:apiVersion=5.5 --diskMode=thin \
"--datastore=${DATASTORE}" -n=${NAME} "--network=${PORTGROUP}" \
${OVA} \
vi://${ADMIN}:'${PASSWORD}'@${TARGET}
EOF

	nohup sh ${MYSCRIPT} >/dev/null 2>&1 & 
}

for i in `cd ~ ; ./list_mail_users.sh`;
do
	NAME="${i}"

	deploy_photonos ${NAME}
done 

exit 0
