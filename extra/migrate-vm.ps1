$sourceVC = 'sourcevc'
$sourceVCUsername = 'administrator@vsphere.local'
$sourceVCPassword= 'password!'

$destVC = 'destinationvc'
$destVCUsername = 'administrator@vsphere.local'
$destVCPassword= 'password'
$destESXi = 'destinationesxi'

$vmname = 'vmname'
$Switchname = 'destinationswitch'
$NetworkName = 'destinationvlan'
$datastorename = 'destinationdatastore'

# Connect to the vCenter Servers
$sourceVCConn = Connect-VIServer -Server $sourceVC -user $sourceVCUsername -password $sourceVCPassword
$destVCConn = Connect-VIServer -Server $destVC -user $destVCUsername -password $destVCPassword
$vm = Get-VM $vmname -Server $sourceVCConn
$networkAdapter = Get-NetworkAdapter -VM $vm -Server $sourceVCConn
 
$destination = Get-VMHost -name $destESXi -Server $destVCConn
$destinationPortGroup = Get-VirtualPortGroup -VirtualSwitch $Switchname -name $NetworkName -VMHost $destination
$destinationDatastore = Get-Datastore -name $datastorename -Server $destVCConn
Move-VM -VM $vm -Destination $destination -NetworkAdapter $networkAdapter -PortGroup $destinationPortGroup -Datastore $destinationDatastore
