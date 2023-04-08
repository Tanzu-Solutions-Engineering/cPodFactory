Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server ###VCENTER### -User ###VCENTER_ADMIN### -Password '###VCENTER_PASSWD###'

# Get the Cluster Object
$VsanCluster = Get-Cluster -Name ###VCENTER_CLUSTER### 

$Enable=$true

# Enumerate all the hosts in the cluster & determine if FakeSCSIReservations are enabled/not based on the input
Foreach ($VMhost in ($VsanCluster | Get-VMHost | Sort-Object Name )) {

    # Retrieve the current setting for Fake SCSI Reservations
    $CurrentFakeSCSISetting = Get-AdvancedSetting -Entity $VMhost -Name "VSAN.FakeSCSIReservations"

        # If the current value differs from the $Enabled parameter then change the state
        Switch ($CurrentFakeSCSISetting.Value){
            "0" {
                If ($Enable -eq $true) {
                    Write-Host "Enabling 'Fake SCSI Reservations' for vSAN on" $VMhost.Name
                    Get-AdvancedSetting -Entity $VMHost -Name "VSAN.FakeSCSIReservations" | Set-AdvancedSetting -Value "1" -Confirm:$False
                } else {
                    Write-Host "'Fake SCSI Reservations' for vSAN already disabled on"$VMHost.Name
                }
            }
            "1" {
                If ($Enable -eq $false) {
                    Write-Host "Disabling 'Fake SCSI Reservations' for vSAN on" $VMhost.Name
                    Get-AdvancedSetting -Entity $VMHost -Name "VSAN.FakeSCSIReservations" | Set-AdvancedSetting -Value "0" -Confirm:$False
                } else {
                    Write-Host "'Fake SCSI Reservations' for vSAN already enabled on"$VMHost.Name
                }

            }
        }
}
