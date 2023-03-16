#!/bin/bash
#bdereims@vmware.com

# generate cpodrouter list:  sed -n "/\tcpod-/p" /etc/hosts | cut -f1 | sort | awk '{printf "\x27" $1":9100" "\x27" ","}'

for CPODROUTER in $( sed -n "/\tcpod-/p" /etc/hosts | cut -f1 | sort ); do
#for CPODROUTER in $( echo "${1}" ); do
	echo "###${CPODROUTER}###"
	#ssh ${CPODROUTER} tdnf -y install make
	#scp -r containers/docker-node-exporter ${CPODROUTER}:.
	#ssh ${CPODROUTER} systemctl start docker
	#ssh ${CPODROUTER} systemctl enable docker
	#ssh ${CPODROUTER} "cd docker-node-exporter ; make build ; make start"
	#scp sbin/node_exporter ${CPODROUTER}:/sbin/.
	#scp systemd/node_exporter.service ${CPODROUTER}:/etc/systemd/system/.
	#ssh ${CPODROUTER} "chmod ugo+r /etc/systemd/system/node_exporter.service"
	#ssh ${CPODROUTER} "chmod ugo+rx /sbin/node_exporter"
	#ssh ${CPODROUTER} "systemctl stop docker"
	#ssh ${CPODROUTER} "systemctl disable docker"
	#ssh ${CPODROUTER} "systemctl daemon-reload"
	#ssh ${CPODROUTER} "systemctl start node_exporter"
	#ssh ${CPODROUTER} "systemctl enable node_exporter"
	#ssh ${CPODROUTER} "rm -fr /var/lib/docker"
	#ssh ${CPODROUTER} "rm -fr /root/docker-*"
	#ssh ${CPODROUTER} "ip link delete link dev docker0"
	ssh ${CPODROUTER} "journalctl --rotate --vacuum-size=50M"
done
