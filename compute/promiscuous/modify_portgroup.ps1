#Mdofity Portgroup
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGTOUP###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

Get-VDPortgroup $Portgroup | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $true -AllowPromiscuous $true
Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "Uplink 2" -StandbyUplinkPort "Uplink 1" -UnusedUplinkPort "Uplink 3"  
Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -UnusedUplinkPort "Uplink 4"  
