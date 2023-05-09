# Let's start with cPodFactory

Welcome to the cPodFactory!

This is the starting point of understanding how to use cPods in your nested environment. Here you will get overview of the components that are essential. As next you see a basic diagram of the solution. 

![cpodfactory diagram](images/basic-cpod-diagram.png)

----
## The cPodFactory components

The basic components of cPodFactory are:

*	**cPodEdge** is a virtual appliance. It is the core of cPodFactory. It is delivered as a OVA and can be downloaded from the central server. It has Linux PhotonOS and some important services. The scripts that build the automation of cPodFactory are included in the OVA image. In addition you have all interfaces you will need to run commands on vSphere, VC, NSX, etc. After connecting and configuring the cPodFactory you will use the **cpodctl** to create new cPods.
	*	The **Network Interfaces** mapping from cPodEdge:
		* **eht0** connects to the **Management** network
		* **eth2** connects to the **Transit** network
		* **eth1** connects to the **external/Internet** network. This can connect to wireguard and openVPN container within the cPodEge if you dont have access over the management network
		* **eth3** not used often. It can offer some services like DHCP. For example to set IPs from NSX TEP interfaces 
*	**cPodRouter** is another virtual appliance. cPodRouters will be dynamically created from cPodRouter template and every cPod (nested environment) will have its own cPodRouter. cPodRouters will be routed together with eBGP and the owners from cPods can interconnect their services.
	* **template-cPodRouter** is created during the initial configuration. All future cPods will get their cPodRouters from it. The eth0 is not connected to any Subnet.
*	The **Transit network** is the subnetwork that is created to connect cPodRouters. During the configuration phase a subnet has to be selected that fulfill this purpose. The cPodEdge is the Gateway in that subnet and is set with the parameter TRANSIT_GW="254.1", that set the subnetwork and the IP from the eth2 interface from cPodEdge.
*	The **cPODs Network** is the network that cPods will share. It is set with the parameter **TRANSIT=** and is usually Class B /16 network. Depending on the Netmask in the cPodRouter the cPods will get usually Class C /24 nested networks.