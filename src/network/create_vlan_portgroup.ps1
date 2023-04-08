#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGROUP###"
$VlanID = "###VLANID###"
$VDS = "###VDS###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

Get-VDSwitch -Name $VDS | New-VDPortgroup -Name $Portgroup -VLanId $VlanID -PortBinding Ephemeral

#####

Disconnect-VIServer -Confirm:$false
