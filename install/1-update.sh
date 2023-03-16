#!/bin/bash
#bdereims@vmware.com

chage -I -1 -m 0 -M 99999 -E -1 root
useradd -U quagga

tdnf -y install awk jq dnsmasq make ntp tmux sshpass iperf socat libpcap 

systemctl enable docker
systemctl start docker

systemctl enable ntpd
systemctl start ntpd

systemctl enable bgpd
systemctl start bgpd
