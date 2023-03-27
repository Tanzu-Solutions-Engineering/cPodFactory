#Create vApp
#vtonev@vmware.com

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

#remove snapshot
Stop-VMGuest "*$cPodName*"  -Confirm:$false
 do { $vmstatus = (get-vm -Name "*$cPodName*" ).PowerState ; Start-Sleep -Seconds 5} while ($vmstatus -eq "PoweredOn")
#remove snapshot
foreach ($vm in  Get-VM -Name  "*$cPodName*") { Get-Snapshot -VM $vm -Name $Portgroup |Remove-Snapshot -RemoveChildren -Confirm:$false}
#poweron VMs
Start-VM "*$cPodName*"  -Confirm:$false
#check if vms powered on
 do { $vmstatus = (get-vm -Name "*$cPodName*" ).PowerState ; Start-Sleep -Seconds 5} while ($vmstatus -ne "PoweredOn")
Start-Sleep -Seconds 15 

Disconnect-VIServer -Confirm:$false
