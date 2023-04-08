$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Domain = "###DOMAIN###"
$vCenterESX = "esx-01."+$Domain
$numberESX = ###NUMESX### 
$startnumESX = ###STARTNUMESX### 
$esxPass = "###ESX_PASSWD###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

$location = Get-Folder -Name Datacenters -NoRecursion
New-DataCenter -Location $location -Name $Datacenter
New-Cluster -Name $Cluster -Location $Datacenter

Write-Host "Add ESX VMs."
For ($i=$startnumESX; $i -le $numberESX; $i++) {
	$ESX_NUMBER=$i.ToString("0#")
        Write-Host "-> esx$ESX_NUMBER"
	Add-VMHost -Server $Vc -Name esx$ESX_NUMBER.$DOMAIN -Location (Get-Cluster -Name $Cluster ) -User root -Password $esxPass -force:$true
	#Get-VMHost | Set-VMHostSysLogServer -SysLogServer $VI_SERVER
	#Get-VMHostStorage -VMHost $vmhost | Set-VMHostStorage -SoftwareIScsiEnabled $True
	Get-VMHostStorage -VMHost ( Get-VMHost ) | Set-VMHostStorage -SoftwareIScsiEnabled $True
}

$VCVM = Get-VM -Name "VCSA"
$vmstartpolicy = Get-VMStartPolicy -VM $VCVM
Set-VMHostStartPolicy (Get-VMHost $vCenterESX | Get-VMHostStartPolicy) -Enabled:$true
Set-VMStartPolicy -StartPolicy $vmstartpolicy -StartAction PowerOn -StartDelay 0

$alarmMgr = Get-View AlarmManager
Get-Cluster | Where-Object {$_.ExtensionData.TriggeredAlarmState} | ForEach-Object{
    $cluster = $_
    $entity_moref = $cluster.ExtensionData.MoRef

    $cluster.ExtensionData.TriggeredAlarmState | ForEach-Object{
        $alarm_moref = $_.Alarm.value

        "Ack'ing $alarm_moref ..." | Out-File -Append -LiteralPath $DeployLogFile
        $alarmMgr.AcknowledgeAlarm($alarm_moref,$entity_moref) | Out-File -Append -LiteralPath $DeployLogFile
    }
}

$thisDataStore = Get-datastore nfsDatastore
get-vmhost | foreach {
	$_ | Get-AdvancedSetting -name "Syslog.global.logDir" | set-advancedsetting -Value "[nfsDatastore] scratch/log" -confirm:$false
	$_ | Get-AdvancedSetting UserVars.SuppressShellWarning | Set-AdvancedSetting -Value 1 -confirm:$false
	#Remove-VmHostNtpServer -NtpServer 172.16.1.1 -VMHost $_ -confirm:$false
	Add-VmHostNtpServer -NtpServer cpodrouter.$Domain -VMHost $_
	Get-VMHostService $_ | where { $_.Key -eq "ntpd" } | Restart-VMHostService -confirm:$false
	$_ | Get-VMHostHba -Type iScsi | New-IScsiHbaTarget -Address cpodfiler.$DOMAIN -confirm:$false
	$_ | Get-VMHostStorage -RescanAllHBA
}


Disconnect-VIServer * -confirm:$false
