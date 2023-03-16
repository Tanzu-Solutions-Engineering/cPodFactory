# Configuring FortyTwo for template creation

## download fortytwo template

on cpodedge run:
```
cpodctl create services 0 <username>
cd /data/BITS
curl -LO https://bucket-garage.s3.eu-central-1.amazonaws.com/template-FORTYTWO-20230112.ova
mv template-FORTYTWO-20230112.ova template-FORTYTWO.ova

```
deploy fortytwo in cpod-services
```
./extra/deploy_fortytwo_atside.sh services vedw
```

add extra HDD to forty-two


set forty-two fixed ip
* edit /etc/netplan/01-netcfg.yaml and change values as needed
```
network:
  version: 2
  renderer: networkd
  ethernets:
    ens192:
      dhcp4: no
      addresses: [172.24.11.42/24]
      gateway4: 172.24.11.1
      nameservers:
        addresses: [172.24.11.1]
```
* apply with : 
```
netplan apply
```

add cpodedge id_rsa.pub to authorized_keys on fortytwo for root

## setup forty-two for cpod templating

on forty-two execute following steps as root:
```
apt-get install genisoimage
wget https://raw.githubusercontent.com/fgrehl/virten-scripts/master/bash/esxi_ks_injector/esxi_ks_iso.sh
chmod +x esxi_ks_iso.sh
./esxi_ks_iso.sh
mkdir -p /tmp/cpod-template
```

## setup wavefront monitoring for vcenter

