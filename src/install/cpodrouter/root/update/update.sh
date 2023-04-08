#!/bin/bash
#bdereims@vmware.com

### Input
# $1: name, ex: vcd
# $2: external ip, ex: 172.16.0.16
# $3: root Domain
# $4: cPodEdge ASN

### Variables
# internal ip = last byte of $1 - 10, ex: 172.18.6.1
# dhcp low = extanel ip but with .200, ex: 172.18.6.200
# dhcp high = extanel ip but with .254, ex: 172.18.6.254
# subnet, ex. 172.18.6.0/24

### Files to be modified
# /etc/hostname
# /etc/hosts
# /etc/dnsmasq.conf
# /etc/exports
# /etc/motd & /etc/issue
# /etc/quagga/bgpd.conf
# /etc/systemd/networkd/eth0-static.network
# /etc/systemd/networkd/eth1-static.network
# /etc/nginx/nginx.conf
# /etc/nginx/html/index.html

DATE=$( date +%F-%X )
echo "${DATE} - Update with: ${1} ${2} ${3} ${4}" > /root/update/update-config

### Constant
NET_INT="172.21"
if [ "$1" == "" -o  "$2" == "" ]; then
        exit 1
fi

NAME=$( echo $1 | tr '[:upper:]' '[:lower:]' )
echo $NAME

IP_TRANSIT=$2
echo ${IP_TRANSIT}

# ==== modified section end ====
#TEMP=$( echo ${IP_TRANSIT} | cut -d '.' -f4 )
#NET=$( expr ${TEMP} - 10 )
NET=$( echo ${IP_TRANSIT} | cut -d '.' -f4 )
IP="${NET_INT}.${NET}.1"
echo $IP
# ==== modified section end ====

TEMP=$( echo ${IP} | sed 's/\.[0-9]*$//' )
DHCP_LOW="${TEMP}.200"
DHCP_HIGH="${TEMP}.254"
SUBNET="${TEMP}.0/24"
echo ${DHCP_LOW}
echo ${DHCP_HIGH}
echo ${SUBNET}

# hostname
echo "### hostname"
cat hostname | sed "s/###NAME###/${NAME}/" > /etc/hostname

# hosts
echo "### hosts"
cat hosts | sed "s/###IP###/${IP}/" > /etc/hosts
printf "${TEMP}.2\tcpodfiler\n" >> /etc/hosts
# dnsmasq.conf
echo "### dnsmasq.conf"
cat dnsmasq.conf | sed -e "s/###NAME###/${NAME}/" -e "s/###IP-TRANSIT###/${IP_TRANSIT}/" -e "s/###IP###/${IP}/" -e "s/###DHCP-LOW###/${DHCP_LOW}/" -e "s/###DHCP-HIGH###/${DHCP_HIGH}/" -e "s/###ROOT_DOMAIN###/${3}/"> /etc/dnsmasq.conf

# exports
echo "### exports"
cat exports | sed "s!###SUBNET###!${SUBNET}!" > /etc/exports

# motd & issue
echo "### motd"
cat motd | sed "s/###NAME###/${NAME}/" > /etc/motd
cp /etc/motd /etc/issue

# bgpd.conf
echo "### bgpd.conf"
TMP=$( echo ${IP_TRANSIT} | cut -d"." -f4 )
ASN=$( expr ${4} + ${TMP} )
cat bgpd.conf | sed -e "s/###IP-TRANSIT###/${IP_TRANSIT}/" -e "s/###ASN_CPODEDGE###/${4}/" -e "s/###ASN###/${ASN}/" > /etc/quagga/bgpd.co
nf
chown quagga:quagga /etc/quagga/bgpd.conf

# eth0-static.network
echo "### eth0-static.network"
cat eth0-static.network | sed "s/###IP###/${IP}/" > /etc/systemd/network/eth0-static.network
chmod ugo+r /etc/systemd/network/eth0-static.network

# eth1-static.network
echo "### eth1-static.network"
cat eth1-static.network | sed "s/###IP-TRANSIT###/${IP_TRANSIT}/" > /etc/systemd/network/eth1-static.network
chmod ugo+r /etc/systemd/network/eth1-static.network

# nginx.conf
echo "### nginx.conf"
cat nginx.conf | sed -e "s/###NAME###/${NAME}/" -e "s/###ROOT_DOMAIN###/${3}/" > /etc/nginx/nginx.conf

# index.html
echo "### index.html"
cat index.html | sed -e "s/###NAME###/${NAME}/" -e "s/###ROOT_DOMAIN###/${3}/" > /etc/nginx/html/index.html

# create /dev/sdb
fdisk -l | grep /dev/sdb1
if [ $? -ne 0 ]; then
        echo "### Creating & Formating Datastore"
        pvcreate /dev/sdb
        vgcreate vg-datastore /dev/sdb
        lvcreate -n lv-datastore -l 100%FREE vg-datastore
        mkfs.ext4 /dev/vg-datastore/lv-datastore
        #echo -e "g\nn\n\n\n\nw\n" | fdisk /dev/sdb
        #mkfs.ext4 /dev/sdb1
        #echo "/dev/sdb1 /data ext4 defaults,barrier,noatime,noacl,data=ordered 1 1" >> /etc/fstab
        echo "/dev/vg-datastore/lv-datastore /data ext4 defaults,barrier,noatime,noacl,data=ordered 1 1" >> /etc/fstab
        mount -a
        mkdir -p /data/Datastore
        chmod 0777 -R /data/Datastore/

        # Extendind VG with other disks
        for DISK in $( fdisk -l | grep "Disk /dev/sd" | awk '{print $2}' | sed -e "s/://" -e "/sda/d" -e "/sdb/d" );
        do
                pvcreate ${DISK}
                vgextend vg-datastore ${DISK}
        done

        lvextend -l +100%FREE /dev/vg-datastore/lv-datastore
        resize2fs /dev/vg-datastore/lv-datastore
fi

# enable services
systemctl enable bgpd
systemctl enable dnsmasq
systemctl enable nfs-server
systemctl enable ntpd
systemctl enable nginx
