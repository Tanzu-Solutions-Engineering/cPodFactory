$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$vlan = '###VLAN###'

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

# get versions
$vcenterversion =  $global:DefaultVIServers | Select Name,Version 
$vmhosts = get-vmhost
$esxiversion =  $vmhosts[0].Version 

 
# Get the Datacenter Object
$Datacenter = Get-Datacenter 

$test = Get-VDSwitch -Name "VDSwitch" -Location $Datacenter  -ErrorAction SilentlyContinue
 
if ($test.count -gt 0) {
    write-host "VDSwitch already exists."
    write-host "quitting process."
    exit
}

# Create the new VDS named VDSwitch
$VDSwitch = New-VDSwitch -Name "VDSwitch" -Location $Datacenter  -Mtu 9000 -NumUplinkPorts 1 -Version $esxiversion
# Use Get-View to set NIOC
$VDSwitchView = Get-View -Id $VDSwitch.Id
$VDSwitchView.EnableNetworkResourceManagement($true)
# Get the vSAN Cluster
$Cluster = Get-Cluster -Name "Cluster"
# Enumerate all the hosts and cycle through them 
Foreach ($ESXhost in ($Cluster | Get-VMHost)) {
    # If the VDS doesn’t exist on the host, add it
    If (-Not (Get-VDSwitch -VMHost $ESXhost | Where-Object {$_.Name -eq "VDSwitch"})) {
        # Add the host to the VDS
        Get-VDSwitch -Name "VDSwitch" | Add-VDSwitchVMHost -VMHost $ESXhost
        # Add pnics 1to the VDS
        $vmhostNetworkAdapter = Get-VMHost $ESXhost | Get-VMHostNetworkAdapter -Physical -Name vmnic1
        Get-VDSwitch $VDSwitch | Add-VDSwitchPhysicalNetworkAdapter -VMHostPhysicalNic $vmhostNetworkAdapter -Confirm:$false 
    } 
}

#add vlans

for ($num = 1 ; $num -le 8 ; $num++){

    if ([int]$vlan -gt 40) {
        $vlanID = $vlan + $num
    }else{
        $vlanID = $vlan + "{0:D2}" -f $num
    } 

    $vlanname = "vlan-" + $vlanID
    Switch ($num){
        1 {$vlanname = $vlanname + "-management"}
        2 {$vlanname = $vlanname + "-workload"}
        3 {$vlanname = $vlanname + "-frontend"}
    }
    write-host $vlanname
    Get-VDSwitch -Name "VDSwitch" | New-VDPortgroup -Name $vlanname  -VLanId $vlanID -runasync
}

#####
Disconnect-VIServer -Confirm:$false
