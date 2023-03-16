#Enter ESX in Maintenance Mode
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$cPodName = "###CPOD_NAME###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#Get-VMHost | set-vmhost -State Maintenance

Foreach ( $VM in Get-VM ) {
	if ( $VM -NotMatch "VCSA" ) {
		Write-Host "shutdown $VM"
		Shutdown-VMGuest -VM $VM -Confirm:$false
	}
}

Foreach ( $ESX in Get-VMHost ) {
	Write-Host "$ESX is going to Maintenance Mode"
	$vmhost= Get-VMHost $ESX 
	$spec = new-object VMware.Vim.HostMaintenanceSpec
	$spec.VsanMode = new-object VMware.Vim.VsanHostDecommissionMode
	$spec.VsanMode.ObjectAction = "ensureObjectAccessibility"
	$vmhost.ExtensionData.EnterMaintenanceMode(0, $false, $spec)
}

Disconnect-VIServer -Confirm:$false
