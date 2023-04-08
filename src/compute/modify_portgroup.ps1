#Modify Portgroup
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = "###VCENTER_PASSWD###"
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGTOUP###"
$Spec = "###SPEC###"

Function Set-MacLearn {
<#
    .NOTES
    ===========================================================================
     Created by:    William Lam
     Organization:  VMware
     Blog:          www.virtuallyghetto.com
     Twitter:       @lamw
        ===========================================================================
    .DESCRIPTION
        This function allows you to manage the new MAC Learning capablitites in
        vSphere 6.7 along with the updated security policies.
    .PARAMETER DVPortgroupName
        The name of Distributed Virtual Portgroup(s)
    .PARAMETER EnableMacLearn
        Boolean to enable/disable MAC Learn
    .PARAMETER EnablePromiscuous
        Boolean to enable/disable the new Prom. Mode property
    .PARAMETER EnableForgedTransmit
        Boolean to enable/disable the Forged Transmit property
    .PARAMETER EnableMacChange
        Boolean to enable/disable the MAC Address change property
    .PARAMETER AllowUnicastFlooding
        Boolean to enable/disable Unicast Flooding (Default $true)
    .PARAMETER Limit
        Define the maximum number of learned MAC Address, maximum is 4096 (default 4096)
    .PARAMETER LimitPolicy
        Define the policy (DROP/ALLOW) when max learned MAC Address limit is reached (default DROP)
    .EXAMPLE
        Set-MacLearn -DVPortgroupName @("Nested-01-DVPG") -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $false
#>
    param(
        [Parameter(Mandatory=$true)][String[]]$DVPortgroupName,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacLearn,
        [Parameter(Mandatory=$true)][Boolean]$EnablePromiscuous,
        [Parameter(Mandatory=$true)][Boolean]$EnableForgedTransmit,
        [Parameter(Mandatory=$true)][Boolean]$EnableMacChange,
        [Parameter(Mandatory=$false)][Boolean]$AllowUnicastFlooding=$true,
        [Parameter(Mandatory=$false)][Int]$Limit=4096,
        [Parameter(Mandatory=$false)][String]$LimitPolicy="DROP"
    )

    foreach ($dvpgname in $DVPortgroupName) {
        $dvpg = Get-VDPortgroup -Name $dvpgname -ErrorAction SilentlyContinue
        $switchVersion = ($dvpg | Get-VDSwitch).Version
        if($dvpg -and $switchVersion -ge "6.6.0") {
            $originalSecurityPolicy = $dvpg.ExtensionData.Config.DefaultPortConfig.SecurityPolicy

            $spec = New-Object VMware.Vim.DVPortgroupConfigSpec
            $dvPortSetting = New-Object VMware.Vim.VMwareDVSPortSetting
            $macMmgtSetting = New-Object VMware.Vim.DVSMacManagementPolicy
            $macLearnSetting = New-Object VMware.Vim.DVSMacLearningPolicy
            $macMmgtSetting.MacLearningPolicy = $macLearnSetting
            $dvPortSetting.MacManagementPolicy = $macMmgtSetting
            $spec.DefaultPortConfig = $dvPortSetting
            $spec.ConfigVersion = $dvpg.ExtensionData.Config.ConfigVersion

            if($EnableMacLearn) {
                $macMmgtSetting.AllowPromiscuous = $EnablePromiscuous
                $macMmgtSetting.ForgedTransmits = $EnableForgedTransmit
                $macMmgtSetting.MacChanges = $EnableMacChange
                $macLearnSetting.Enabled = $EnableMacLearn
                $macLearnSetting.AllowUnicastFlooding = $AllowUnicastFlooding
                $macLearnSetting.LimitPolicy = $LimitPolicy
                $macLearnsetting.Limit = $Limit

                Write-Host "Enabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
            } else {
                $macMmgtSetting.AllowPromiscuous = $false
                $macMmgtSetting.ForgedTransmits = $false
                $macMmgtSetting.MacChanges = $false
                $macLearnSetting.Enabled = $false

                Write-Host "Disabling MAC Learning on DVPortgroup: $dvpgname ..."
                $task = $dvpg.ExtensionData.ReconfigureDVPortgroup_Task($spec)
                $task1 = Get-Task -Id ("Task-$($task.value)")
                $task1 | Wait-Task | Out-Null
            }
        } else {
            Write-Host -ForegroundColor Red "Unable to find DVPortgroup $dvpgname or VDS is not running 6.6.0"
            break
        }
    }
}

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

#Get-VDPortgroup $Portgroup | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $true -AllowPromiscuous $true
#Get-VDPortgroup $Portgroup | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $true -AllowPromiscuous $false

switch ($Spec) {
	"OVH" {
		$unusedPortsList = "pcc-178-32-194-72_DC3594-vrack_up1", "pcc-178-32-194-72_DC3594-vrack_up2", "pcc-178-32-194-72_DC3594-vrack_up3"
		Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "lag1" -UnusedUplinkPort $unusedPortsList -LoadBalancingPolicy LoadBalanceIP
		Break
	}
	"SHWRFR" {
		Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "Uplink 2" -StandbyUplinkPort "Uplink 1"
		Break
	}
	"FKD" {
		Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "uplink2" -StandbyUplinkPort "uplink1"
		Break
	}
	"TECHDATA" {
		$unusedPortsList = "uplink3", "uplink4"
		Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "uplink1" -StandbyUplinkPort "uplink2" -UnusedUplinkPort $unusedPortsList
		Break
	}
	"LAB" {
		Get-VDPortgroup $Portgroup | Get-VDUplinkTeamingPolicy | Set-VDUplinkTeamingPolicy -ActiveUplinkPort "Uplink 1" -StandbyUplinkPort "Uplink 2"
		Break
	}    
}
#Get-VDPortgroup $Portgroup | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $true -AllowPromiscuous $false -MacChanges $true
Set-MacLearn -DVPortgroupName @($Portgroup) -EnableMacLearn $true -EnablePromiscuous $false -EnableForgedTransmit $true -EnableMacChange $true
#Get-VDPortgroup $Portgroup | Get-VDSecurityPolicy | Set-VDSecurityPolicy -ForgedTransmits $true -AllowPromiscuous $true -MacChanges $true

#####

Disconnect-VIServer -Confirm:$false
