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

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#####

Stop-VApp -VApp PhotonOS -Confirm:$false

#$Vapp = Get-VApp -Name 'PhotonOS'

#$VAppView = $Vapp | Get-View
ForEach ($Entity in Get-VM -Location ( Get-VApp -Name 'PhotonOS' ) ) {
	Remove-VM -VM $Entity -DeleteFromDisk -Confirm:$false -RunAsync
}

#Invoke-VMScript -VM $vmName -ScriptText "date > log ; echo -n > /etc/machine-id ; echo $vmName > /etc/hostname" -GuestUser root -GuestPassword $rootPasswd -scripttype Bash -ToolsWaitSecs 45

#Restart-VM -VM $vmName -Confirm:$false

Disconnect-VIServer -Confirm:$false
