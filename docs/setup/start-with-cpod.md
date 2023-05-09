# Let's start with cPodFactory

Welcome to the cPodFactory!

This is the starting point of understanding how to use cPods in your nested environment. Here you will get overview of the components that are essential. As next you see a basic diagram of the solution. 

![new transport zone](images/basic-cpod-diagram.png)

----
## The cPodFactory components

The basic components of cPodFactory are:

* **cPodEdge** is a virtual appliance. It is the core of cPodFactory. It is delivered as a OVA and can be downloaded from the central server. It has Linux PhotonOS and some important services. The scripts that build the automation of cPodFactory are included in the OVA image. In addition you have all interfaces you will need to run commands on vSphere, VC, NSX, etc. After connecting and configuring the cPodFactory you will use the **cpodctl** to create new cPods.
* **cPodRouter** is another virtual appliance. cPodRouters will be dynamically created from cPodRouter template and every cPod (nested environment) will have its own cPodRouter. cPodRouters will be routed together with eBGP and the owners from cPods can interconnect their services.
