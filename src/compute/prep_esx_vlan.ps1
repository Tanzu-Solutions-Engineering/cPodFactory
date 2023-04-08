#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$cPodName = "###CPOD_NAME###"
$Password = "###PASSWORD###"
$VLAN = "###VLAN###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

Write-Host "Modify ESX VMs network interfaces"

$ResPool = Get-ResourcePool -Name cPod-$cPodName -Location ( Get-Datacenter -Name $Datacenter )

$ListESX = $ResPool | Get-VM | where { $_.name -match "esx" } 
ForEach ($Entity in $ListESX) {
	Write-Host "$Entity"
	Get-NetworkAdapter -VM $Entity | Where {$_.NetworkName -ne "Trunk" } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name "Trunk" ) -Confirm:$false
}

#####

Disconnect-VIServer -Confirm:$false
