#!/bin/bash
#bdereims@vmware.com

INTERFACE=eth2
BIG_MTU=9000
REG_MTU=1500
VLANID=$( ip addr show eth1 | grep inet | head -1 | awk '{print $2}' | sed 's/\/.*$//' | sed -e "s/^.*\.//" )

create_vlan() 
{
	VLAN=${VLANID}${2}
	SUBNET=$( echo ${2} | sed -e "s/0//" )
	ip link add link ${INTERFACE} name ${INTERFACE}.${VLAN} type vlan id ${VLAN} 
	ip addr add 10.${VLANID}.${SUBNET}.1/${3} dev ${INTERFACE}.${VLAN}
	ip link set mtu ${1} dev ${INTERFACE}.${VLAN}
	ip link set up ${INTERFACE}.${VLAN}
}

# vMOTION + vSAN
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${BIG_MTU} 1 24
else
	create_vlan ${BIG_MTU} 01 24
fi

# TEP Edges
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${BIG_MTU} 2 24
else
	create_vlan ${BIG_MTU} 02 24
fi

# TEP Hosts
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${BIG_MTU} 3 24
else
	create_vlan ${BIG_MTU} 03 24
fi

# General purpose VLAN 
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${REG_MTU} 4 24
else
	create_vlan ${REG_MTU} 04 24
fi

# General purpose VLAN 
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${REG_MTU} 5 24
else
	create_vlan ${REG_MTU} 05 24
fi

# General purpose VLAN 
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${REG_MTU} 6 24
else
	create_vlan ${REG_MTU} 06 24
fi

# General purpose VLAN 
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${REG_MTU} 7 24
else
	create_vlan ${REG_MTU} 07 24
fi

# General purpose VLAN
if [ ${VLANID} -gt 40 ]; then
	create_vlan ${REG_MTU} 8 24
else
	create_vlan ${REG_MTU} 08 24
fi
# Expose/Uplink - Large Subnet
# Ex. of Carve Out: 10.12.8.0/21 = 10.12.8.0/22 + 10.12.12.0/22
# Ex. of Carve Out: 10.12.8.0/21 = 10.12.8.0/24 + 10.12.9.0/24 + 10.12.10.0/23 + 10.12.12.0/22
