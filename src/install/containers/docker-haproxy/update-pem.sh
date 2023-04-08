#/bin/bash

PEM_FILE=haproxy/conf/cpodedge.pem
#DOMAIN=az-lab.shwrfr.com
DOMAIN=shwrfr.com
ACME=~/.acme.sh/${DOMAIN}

cat ${ACME}/fullchain.cer ${ACME}/${DOMAIN}.key > ${PEM_FILE}
