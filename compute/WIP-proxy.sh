#!/bin/bash
#bdereims@vmware.com

#for squid proxy on cPodRouter
#docker run -d -p 3128:3128 --dns=172.16.1.1 b4tman/squid

. ./env

[ "${1}" == ""  -o "${2}" == "" ] && echo "usage: ${0} CPOD-NAME enable|disable" && exit 1
CPODROUTER=$( echo ${1} | tr '[:upper:]' '[:lower:]' )

echo "=== Air-Gapping ${1} with ${2} on cPodRouter" 

rexec() {
	ssh -o LogLevel=ERROR ${CPODROUTER} ${1}
}

case ${2} in
	enable)
		# Accept only RFC1918
		echo ""
		rexec "iptables -P FORWARD DROP ; iptables -A FORWARD -d 10.0.0.0/8 -j ACCEPT ; iptables -A FORWARD -d 172.16.0.0/12 -j ACCEPT ; iptables -A FORWARD -d 192.168.0.0/16 -j ACCEPT ; iptables -xnvL"
		echo ""
		echo "Enable! ${1} now without Internet connectivity."
		;;
	disable)
		echo ""
		rexec "iptables -P FORWARD ACCEPT ; iptables -D FORWARD -d 10.0.0.0/8 -j ACCEPT ; iptables -D FORWARD -d 172.16.0.0/12 -j ACCEPT ; iptables -D FORWARD -d 192.168.0.0/16 -j ACCEPT ; iptables -xnvL"
		echo ""
		echo "Disable! ${1} with Internet connectivity"
		;;
esac




# https://devopscube.com/setup-and-configure-proxy-server/
# https://www.digitalocean.com/community/tutorials/how-to-set-up-squid-proxy-on-ubuntu-20-04
# tdnf install squid
# tdnf install httpd 
# to get htpasswd ?
#
# htpasswd -c /etc/squid/passwd proxyuser
# htpasswd -b /etc/squid/passwd proxyuser "VMware1!"
# htpasswd -b /etc/squid/passwd crazyproxyuser "PasswordWith-Special{-chars"

# fix tdnf repos
# sed  -i 's/dl.bintray.com\/vmware/packages.vmware.com\/photon\/$releasever/g' photon.repo photon-updates.repo photon-extras.repo photon-debuginfo.repo
# sed  -i 's/dl.bintray.com\/vmware/packages.vmware.com\/photon\/$releasever/g' /etc/yum.repos.d/photon*.repo 
# ssh cpod-edge01.az-stc.cloud-garage.net "sed  -i 's=dl.bintray.com=/vmware/packages.vmware.com/photon/$releasever=g' /etc/yum.repos.d/photon*.repo"
# 
#
# install and configure squid
# create user passwords
# airgap cpod


# squid.conf edits :

# should be allowed
#acl localnet src 0.0.0.1-0.255.255.255	# RFC 1122 "this" network (LAN)
#acl localnet src 10.0.0.0/8		# RFC 1918 local private network (LAN)
#acl localnet src 100.64.0.0/10		# RFC 6598 shared address space (CGN)
#acl localnet src 169.254.0.0/16 	# RFC 3927 link-local (directly plugged) machines
#acl localnet src 172.16.0.0/12		# RFC 1918 local private network (LAN)
#acl localnet src 192.168.0.0/16		# RFC 1918 local private network (LAN)
#acl localnet src fc00::/7       	# RFC 4193 local private network range
#acl localnet src fe80::/10      	# RFC 4291 link-local (directly plugged) machines

acl cpod-tzalb03 src 172.24.5.0/24          # RFC 1918 local private network (LAN)

acl SSL_ports port 443
acl Safe_ports port 80		# http
acl Safe_ports port 21		# ftp
acl Safe_ports port 443		# https
acl Safe_ports port 70		# gopher
acl Safe_ports port 210		# wais
acl Safe_ports port 1025-65535	# unregistered ports
acl Safe_ports port 280		# http-mgmt
acl Safe_ports port 488		# gss-http
acl Safe_ports port 591		# filemaker
acl Safe_ports port 777		# multiling http
acl CONNECT method CONNECT

# User authentication
auth_param basic program /usr/lib/squid/basic_ncsa_auth /etc/squid/passwd
auth_param basic realm proxy
acl authenticated proxy_auth REQUIRED
http_access allow authenticated


