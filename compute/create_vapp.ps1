#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGROUP###"
$oldNet = "Dummy"
$cPodName = "###CPOD_NAME###"
$templateVM = "###TEMPLATE_VM###"
$templateESX = "###TEMPLATE_ESX###"
$IP = "###IP###"
$rootPasswd = "###ROOT_PASSWD###"
$Datastore = "###DATASTORE###"
$numberESX = ###NUMESX###
$rootDomain = "###ROOT_DOMAIN###"
$asn = "###ASN###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

#$policy = Get-SpbmStoragePolicy -Name "cPodPolicy"

Write-Host "Create vApp."
$Vapp = New-VApp -Name cPod-$cPodName -Location ( Get-Cluster -Name $Cluster ) 

Write-Host "Add cPodRouter VM."
$CpodRouter = New-VM -Name cPod-$cPodName-cpodrouter -VM $templateVM -ResourcePool $Vapp -Datastore $Datastore

Write-Host "Add Disk for /data in cPodRouter."
$CpodRouter | New-HardDisk -StorageFormat Thin -CapacityGB 2000

Write-Host "Modify cPodRouter vNIC."
Get-NetworkAdapter -VM $CpodRouter | Where {$_.NetworkName -eq $oldNet } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name $Portgroup ) -Confirm:$false
Start-VM -VM $CpodRouter -Confirm:$false 

Start-Sleep -s 5 

Write-Host "Launch Update script in the cPod context."
Invoke-VMScript -VM $CpodRouter -ScriptText "cd update ; ./update.sh $cPodName $IP $rootDomain $asn ; sync ; reboot" -GuestUser root -GuestPassword $rootPasswd -scripttype Bash -ToolsWaitSecs 20 -RunAsync
if ($numberESX -lt 2) {
	Start-Sleep -s 20 
}

#####
Write-Host "Add ESX VMs."
For ($i=1; $i -le $numberESX; $i++) {
	Write-Host "-> cPod-$cPodName-esx-$i"
	$ESXVM = New-VM -Name cPod-$cPodName-esx-$i -VM $templateESX -ResourcePool $Vapp -Datastore $Datastore

	# Adding Disk for vVSAN
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 48 
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 256 

	# Local Datastore for VCSA on ESX-01
	if ($i -eq 1) {
		$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 300
	}
	
	Get-NetworkAdapter -VM $ESXVM | Where {$_.NetworkName -eq $oldNet } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name $Portgroup ) -Confirm:$false

	Start-VM -VM cPod-$cPodName-esx-$i -Confirm:$false -RunAsync 
}

#####
Write-Host "Modify vApp for shutdown."
$VAppView = $Vapp | Get-View
ForEach ($Entity in $VAppView.VAppConfig.EntityConfig) {
	If ($Entity.StopAction -ne "guestShutdown") {
		$VAppConfigSpec = New-Object VMware.Vim.VAppConfigSpec
		$EntityConfig = New-Object VMware.Vim.VAppEntityConfigInfo
		$EntityConfig.Key = (Get-View $Entity.Key).MoRef
		$EntityConfig.StopAction = "guestShutdown"
		$VAppConfigSpec.EntityConfig = $EntityConfig
 
		$VAppView.UpdateVAppConfig($VAppConfigSpec)
	}
}

Disconnect-VIServer -Confirm:$false
