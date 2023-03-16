#this script must be run  as root in /root
#apt list genisoimage
apt-get install genisoimage
wget https://raw.githubusercontent.com/fgrehl/virten-scripts/master/bash/esxi_ks_injector/esxi_ks_iso.sh
chmod +x esxi_ks_iso.sh
./esxi_ks_iso.sh
mkdir -p /tmp/cpod-template


#cat /root/.ssh/id_rsa.pub > /root/.ssh/authorized_keys