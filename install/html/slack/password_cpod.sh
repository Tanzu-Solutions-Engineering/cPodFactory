#/bin/sh

if [ "$1" == "bdereims" ]; then 
 LIST=$( cat /etc/hosts | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print "*"toupper($2)"* > "$4"   "}' | tr -d '\n' )
else
 LIST=$( cat /etc/hosts | grep $1 | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print "*"toupper($2)"* > "$4"   "}' | tr -d '\n' )
fi

echo "cPod Password: ${LIST}"
exit 0

for CPOD in $( cat /etc/hosts | grep $1 | sed "s/#//" | awk '$2 ~ /cpod-/ {gsub(/cpod-/,""); print "*"toupper($2)"* : "$4}' ); do
        LIST="#${LIST}#    #${CPOD}#"
done

echo "cPod Password: ${LIST}"
