#Delete vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$cPodName = "###CPOD_NAME###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

###

$ResPool = Get-ResourcePool -Name cPod-$cPodName -Location ( Get-Datacenter -Name $Datacenter ) 

$ListVM = $ResPool | Get-VM
ForEach ($Entity in $ListVM) {
	Stop-VM -VM $Entity -Confirm:$false
	Remove-VM -VM $Entity -DeletePermanently -Confirm:$false
}

Remove-ResourcePool -ResourcePool $ResPool -Confirm:$false

###

Disconnect-VIServer -Confirm:$false
