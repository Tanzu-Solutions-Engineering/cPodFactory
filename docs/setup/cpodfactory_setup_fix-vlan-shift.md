# Fixing cpodfactory cpod network alignment

originaly cpods have a delta of -10 between cpod management network and their vlans
example :
```
172.24.1.0/24 via 172.16.2.11 dev eth2 proto zebra metric 20
172.24.2.0/24 via 172.16.2.12 dev eth2 proto zebra metric 20
172.24.3.0/24 via 172.16.2.13 dev eth2 proto zebra metric 20
172.24.5.0/24 via 172.16.2.15 dev eth2 proto zebra metric 20
```

In this list, cpod #1 has:
* cpodrouter ip = 172.16.2.11
* cpod management network = 172.24.1.0/24
* cpod vlans = 10.11.x.0/24

for readability, in january 2023 i modified scripts in order to get the following result :
* cpodrouter ip = 172.16.2.11
* cpod management network = 172.24.11.0/24
* cpod vlans = 10.11.x.0/24

## updates to code base

git pull fork / dom-cobb past january 24th 2023.
see [setup git](cpodfactory_setup_git.md)

## updates to cpodfactory setup

### modify cpodrouter template

- download new template :

or perform the following changes on cpodrouter
- power-on cpodrouter
- ssh to cpodrouter (using dhcp address)
- modify following files on cpodrouter:
    * /root/vlan.sh - see file content: [vlan.sh](../../install/vlan.sh)
    * /root/update/update.sh - see file content : [update/update.sh](../../install/cpodrouter/root/update/update.sh)  - modified section (line 43->)

- check as well :
    * /root/update/ssd_esx_tag.sh 

### modify dnsmasq on cpodedge for shifting cpod addresses

edit /etc/dnsmasq.conf - line starting with "server=/cpod-start" - to shift 

```
grep "server=/cpod-start" /etc/dnsmasq.conf
```

example - LAB starting at .63  => first cpod will be .64
```
server=/cpod-start.az-lab.cloud-garage.net/172.30.1.63
```
add fake one to force provision above certain number if existing cpods must be kept running
```
server=/cpod-resume.az-lab.cloud-garage.net/172.30.1.63
```
