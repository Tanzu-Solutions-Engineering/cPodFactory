$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

$ClusterHosts = Get-VMHost

#prepare network and disks
Foreach($VMHost in $ClusterHosts)
{
    Write-Host "========"
    Write-Host "host : " $VMHost

    Write-Host "setting disks as flash on host" 
    $LunIDs = Get-ScsiLun -VmHost $VMHost | Where { $_.CapacityGB -gt 100 } | select ConsoleDeviceName,CapacityGB
    $storSys = Get-View -Id $VMHost.ExtensionData.ConfigManager.StorageSystem

    Foreach($LUNid in $LunIDs)
    {
        write-host "    " $LUNid.ConsoleDeviceName " - " $LUNid.CapacityGB "GB"
        $uuid = $storSys.StorageDeviceInfo.ScsiLun | where{$_.DevicePath -eq $LUNid.ConsoleDeviceName } | select uuid,ssd
        write-host "       " $uuid.Uuid " - SSD: " $uuid.Ssd
        if ($uuid.Ssd -eq $false) 
        {
            write-host "marking as flash"
            $storSys.MarkAsSsd($uuid.Uuid) 
        }
    }

} 

Write-Host "========"
Write-Host "==DONE=="
Write-Host "========"

#####
Disconnect-VIServer -Confirm:$false