#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGROUP###"
$cPodName = "###CPOD_NAME###"
$oldNet = "Dummy"
$templateFILER = "###TEMPLATE_FILER###"
$IP = "###IP###"
$rootPasswd = "###ROOT_PASSWD###"
$Datastore = "###DATASTORE###"
$rootDomain = "###ROOT_DOMAIN###"
$genPASSWD = "###GEN_PASSWD###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

#$Vapp = Get-Vapp cPod-$cPodName
$Vapp = Get-ResourcePool -Name cPod-$cPodName

Write-Host "Add cPodFiler VM."
$CpodFiler = New-VM -Name cPod-$cPodName-cpodfiler -VM $templateFILER -ResourcePool $Vapp -Datastore $Datastore

Write-Host "Add Disk for /data in cPodFiler."
$CpodFiler | New-HardDisk -StorageFormat Thin -CapacityKB 5000000000 

Write-Host "Modify cPodFiler vNIC."
Get-NetworkAdapter -VM $CpodFiler | Where {$_.NetworkName -eq $oldNet } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name $Portgroup ) -Confirm:$false
Start-VM -VM $CpodFiler -Confirm:$false 
Start-Sleep -s 5

Write-Host "Launch Update script in the cPod context."
$CpodFiler = Get-VM -name cPod-$cPodName-cpodfiler 

Invoke-VMScript -VM $CpodFiler -ScriptText "cd update ; ./update.sh $cPodName $IP $rootDomain $genPASSWD ; sync ; reboot" -GuestUser root -GuestPassword $rootPasswd -scripttype Bash -ToolsWaitSecs 15 -RunAsync 

Start-Sleep -Seconds 15 
Restart-VM -VM $CpodFiler -Confirm:$false -RunAsync

Disconnect-VIServer -Confirm:$false
