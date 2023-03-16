#Create PhotonOS VM 
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$vmName = "###VM_NAME###"
$templateVM = "###TEMPLATE_VM###"
$rootPasswd = "###ROOT_PASSWD###"
$Datastore = "###DATASTORE###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

$Vapp = Get-VApp -Name 'PhotonOS'

$VAppView = $Vapp | Get-View
ForEach ($Entity in $VAppView.VAppConfig.EntityConfig) {
	$VAppConfigSpec = New-Object VMware.Vim.VAppConfigSpec
	$EntityConfig = New-Object VMware.Vim.VAppEntityConfigInfo
	$EntityConfig.Key = (Get-View $Entity.Key).MoRef
	$EntityConfig.StopAction = "guestShutdown"
	$EntityConfig.StartOrder = 1
	$EntityConfig.StartDelay = 1
	$VAppConfigSpec.EntityConfig = $EntityConfig

	$VAppView.UpdateVAppConfig($VAppConfigSpec)
}

Start-VApp -VApp PhotonOS

sleep 45 

ForEach ($Entity in Get-VM -Location $Vapp ) {
	Invoke-VMScript -VM $Entity -ScriptText "date > log ; echo -n > /etc/machine-id ; echo $Entity > /etc/hostname" -GuestUser root -GuestPassword $rootPasswd -scripttype Bash -ToolsWaitSecs 45
}

sleep 30  

Stop-VApp -VApp $Vapp -Force -Confirm:$false

sleep 15

Start-VApp -VApp $Vapp 

sleep 15

Disconnect-VIServer -Confirm:$false
