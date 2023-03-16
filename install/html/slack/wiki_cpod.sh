#/bin/sh

HEADER="https://vcsa."
FOOTER=".shwrfr.mooo.com"

if [ "x$1" = "x" ]; then 

LIST="Direct link to the wiki:"

for CPOD in $( cat /etc/hosts | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print toupper($2)"("$3")"}' ); do
        FQDN=$( echo ${CPOD} | cut -f1 -d"(" | tr [:upper:] [:lower:] )
        FQDN="http://photon-machine.cpod-common.az-demo.shwrfr.com:8082/dokuwiki/doku.php?id=cpods:${FQDN}"
        CPOD=$( echo ${CPOD} | sed "s/()//" | sed "s/(/ (/" )
        LIST="${LIST}     <${FQDN}|$CPOD>"
done

else

for CPOD in $( cat /etc/hosts | grep $1 | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print toupper($2)}' ); do
        FQDN=$( echo ${CPOD} | cut -f1 -d"(" | tr [:upper:] [:lower:] )
        FQDN="http://photon-machine.cpod-common.az-demo.shwrfr.com:8082/dokuwiki/doku.php?id=cpods:${FQDN}"
        #CPOD=$( echo ${CPOD} | sed "s/()//" | sed "s/(/ (/" )
        LIST="${LIST}     <${FQDN}|$CPOD>"
done

fi

echo "${LIST}"
