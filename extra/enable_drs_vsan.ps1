$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

Function Add-VsanHostDiskGroup {
    # Set our Parameters
    [CmdletBinding()]Param(
        [Parameter(Mandatory=$True)][string]$VMHost,
        [Parameter(Mandatory = $true)][Int]$CacheMax
    )
    # Get all of the local disks that are eligible for vSAN use
    $VsanHostDisks = Get-VMHost -Name $VMHost | Get-VMHostHba | Get-ScsiLun | Where-Object {$_.VsanStatus -eq "Eligible"}
    # There must be at least 2 disks
    # Need to add a check to make sure at least 1 flash and 1 capacity
    If ($VsanHostDisks.Count -gt 1) {
        $CacheDisks = @()
        $CapacityDisks = @()
        # Enumerate through each of the disks.
        Foreach ($VsanDisk in $VsanHostDisks) {
            # Device is tagged as SSD and less than the max size? It is a cache device
            If ($VsanDisk.IsSsd -eq $true -and $VsanDisk.CapacityGB -lt $CacheMax) {
                $CacheDisks +=$VsanDisk
            } else {
                $CapacityDisks +=$VsanDisk
            }
        } 
    }

    $counter = [pscustomobject] @{ Value = 0 }
    Switch ($CacheDisks.Count) {
        "1" {
            Write-Host "Creating 1 Disk Group because there is only 1 cache device"
            $MaxGroup = 7
            }
        {($_ -gt 1) -and ($_ -lt 6)} {
            Write-Host "Creating 2 Disk Groups"
            $groupSize = [math]::floor($CapacityDisks.Count / $CacheDisks.Count)
            }
        }
        $DiskGroups = $CapacityDisks | Group-Object -Property { [math]::Floor($counter.Value++ / $groupSize) }
        $i=0
        Foreach ($CacheDisk in $CacheDisks) {
            # Create a new Disk Group
            Write-Host "Adding Disk Group "$i
            New-VsanDiskGroup  -VMHost $VMHost -SsdCanonicalName $CacheDisk -DataDiskCanonicalName $DiskGroups[$i].Group -RunAsync
            $i = $i+1
    }
}


Write-Host "disabling HA"
Set-Cluster -Cluster "Cluster" -HAEnabled $false -DrsEnabled $false -Confirm:$false 

$ClusterHosts = Get-VMHost

#prepare network and disks


Foreach($VMHost in $ClusterHosts)
{
    Write-Host "========"
    Write-Host "host : " $VMHost

    Write-Host "enabling vmotion and vsan on vmk0"
    $vmk0 = Get-VMHostNetworkAdapter -VmHost $VMHost  -Name "vmk0" 
    Set-VMHostNetworkAdapter -VirtualNic $vmk0 -VsanTrafficEnabled $true -VMotionEnabled $true -Confirm:$false 
   

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

# ENABLe VSAN

Write-Host "Enabling VSAN"
Set-Cluster -Cluster "Cluster" -VsanEnabled $true -Confirm:$false 

Foreach($VMHost in $ClusterHosts)
{
    Write-Host "========"
    Write-Host "host : " $VMHost

    Write-Host "add vsan disk group"

    Add-VsanHostDiskGroup -VMHost $VMHost -CacheMax 400 
} 

Write-Host "Clearing default VSAN Health Check Alarms, not applicable in Nested ESXi env ..."
$alarmMgr = Get-View AlarmManager -Server $vc
Get-Cluster -Server $vc | where {$_.ExtensionData.TriggeredAlarmState} | %{
    $cluster = $_
    $Cluster.ExtensionData.TriggeredAlarmState | %{
        $alarmMgr.AcknowledgeAlarm($_.Alarm,$cluster.ExtensionData.MoRef)
    }
}
$alarmSpec = New-Object VMware.Vim.AlarmFilterSpec
$alarmMgr.ClearTriggeredAlarms($alarmSpec)

Write-Host "Enabling HA and DRS"
Set-Cluster -Cluster "Cluster" -HAEnabled $true -DrsEnabled $true  -DrsAutomationLevel FullyAutomated -Confirm:$false 

#####
Disconnect-VIServer -Confirm:$false