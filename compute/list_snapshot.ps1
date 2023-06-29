#Create vApp
#vtonev@vmware.com
# Set-PowerCLIConfiguration -Scope Session  -ParticipateInCEIP $false | Out-Null

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

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple | Out-Null
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass | Out-Null

#####

#list snapshot
foreach ($vm in  Get-VM -Name  "*$cPodName*") { Get-Snapshot -VM $vm | Select-Object -Property VM, Name, SizeGB, Children}

Disconnect-VIServer -Confirm:$false | Out-Null
