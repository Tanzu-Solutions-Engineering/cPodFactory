$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Portgroup = "###PORTGROUP###"
$templateVMName = "###TEMPLATE_NAME###"
$isofile = "###ISO_FILE###"

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#shutdown the VM
Try{
    $vm = Get-VM -Name $templateVMName -ErrorAction Stop
    switch($vm.PowerState){
        'poweredon' {
            Shutdown-VMGuest -VM $vm -Confirm:$false
            while($vm.PowerState -eq 'PoweredOn'){
                sleep 5
                $vm = Get-VM -Name $templateVMName
            }
        }
        Default {
        Write-Host "VM '$($templateVMName)' is not powered on!"
        }
    }
    Write-Host "$($templateVMName) has shutdown. It should be ready for configuration."
}

Catch{
   Write-Host "VM '$($templateVMName)' not found!"
}

Write-Host "Sleep 30"
Start-Sleep -Seconds 30

#remove cdrom

$vm = Get-VM -Name $templateVMName
$cd = Get-CDDrive -VM $vm
Set-CDDrive -CD $cd -NoMedia -Confirm:$false -ErrorAction Stop


#Set Network adapters to Dummy
Get-vm $templateVMName  | Get-NetworkAdapter | Set-NetworkAdapter -Portgroup Dummy -Confirm:$false
Get-vm $templateVMName  | Get-NetworkAdapter


#####

Disconnect-VIServer -Confirm:$false