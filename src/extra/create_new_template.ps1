$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Portgroup = "###PORTGROUP###"
$templateVMName = "###TEMPLATE_NAME###"
$isofile = "###ISO_FILE###"
$folderName = "###FOLDERNAME###"
$resourcePool = "###RESOURCEPOOLNAME###"
$datastore = "[###DATASTORE###]"

$numcpu=8
$MemoryMB=98304

Set-PowerCLIConfiguration -Scope User -ParticipateInCEIP $false  -Confirm:$false
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

Write-Host "creating VM : '$($templateVMName)'"

#---------------CreateVM_Task---------------
$config = New-Object VMware.Vim.VirtualMachineConfigSpec
$config.NumCPUs = 8
$config.NestedHVEnabled = $true
$config.Flags = New-Object VMware.Vim.VirtualMachineFlagInfo
$config.Flags.VirtualMmuUsage = 'automatic'
$config.Flags.MonitorType = 'release'
$config.Flags.EnableLogging = $true
$config.VirtualSMCPresent = $false
$config.CpuFeatureMask = New-Object VMware.Vim.VirtualMachineCpuIdInfoSpec[] (0)
$config.Tools = New-Object VMware.Vim.ToolsConfigInfo
$config.Tools.BeforeGuestShutdown = $true
$config.Tools.ToolsUpgradePolicy = 'manual'
$config.Tools.BeforeGuestStandby = $true
$config.Tools.AfterResume = $true
$config.Tools.SyncTimeWithHostAllowed = $true
$config.Tools.AfterPowerOn = $true
$config.LatencySensitivity = New-Object VMware.Vim.LatencySensitivity
$config.LatencySensitivity.Level = 'normal'
$config.VirtualICH7MPresent = $false
$config.MemoryMB = 98304
$config.BootOptions = New-Object VMware.Vim.VirtualMachineBootOptions
$config.BootOptions.BootRetryEnabled = $false
$config.BootOptions.EfiSecureBootEnabled = $false
$config.BootOptions.BootRetryDelay = 10000
$config.BootOptions.BootDelay = 0
$config.BootOptions.EnterBIOSSetup = $false
$config.CpuAllocation = New-Object VMware.Vim.ResourceAllocationInfo
$config.CpuAllocation.Shares = New-Object VMware.Vim.SharesInfo
$config.CpuAllocation.Shares.Shares = 8000
$config.CpuAllocation.Shares.Level = 'normal'
$config.CpuAllocation.Limit = -1
$config.CpuAllocation.Reservation = 0


$config.DeviceChange = New-Object VMware.Vim.VirtualDeviceConfigSpec[] (6)
$config.DeviceChange[0] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[0].Device = New-Object VMware.Vim.VirtualMachineVideoCard
$config.DeviceChange[0].Device.NumDisplays = 1
$config.DeviceChange[0].Device.UseAutoDetect = $false
$config.DeviceChange[0].Device.ControllerKey = 100
$config.DeviceChange[0].Device.UnitNumber = 0
$config.DeviceChange[0].Device.Use3dRenderer = 'automatic'
$config.DeviceChange[0].Device.Enable3DSupport = $false
$config.DeviceChange[0].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[0].Device.DeviceInfo.Summary = 'Video card'
$config.DeviceChange[0].Device.DeviceInfo.Label = 'Video card '
$config.DeviceChange[0].Device.Key = 500
$config.DeviceChange[0].Device.VideoRamSizeInKB = 4096
$config.DeviceChange[0].Operation = 'add'


$config.DeviceChange[1] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[1].Device = New-Object VMware.Vim.ParaVirtualSCSIController
$config.DeviceChange[1].Device.SharedBus = 'noSharing'
$config.DeviceChange[1].Device.ScsiCtlrUnitNumber = 7
$config.DeviceChange[1].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[1].Device.DeviceInfo.Summary = 'New SCSI controller'
$config.DeviceChange[1].Device.DeviceInfo.Label = 'New SCSI controller'
$config.DeviceChange[1].Device.Key = -101
$config.DeviceChange[1].Device.BusNumber = 0
$config.DeviceChange[1].Operation = 'add'


$config.DeviceChange[2] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[2].FileOperation = 'create'
$config.DeviceChange[2].Device = New-Object VMware.Vim.VirtualDisk
$config.DeviceChange[2].Device.CapacityInBytes = 17179869184
$config.DeviceChange[2].Device.StorageIOAllocation = New-Object VMware.Vim.StorageIOAllocationInfo
$config.DeviceChange[2].Device.StorageIOAllocation.Shares = New-Object VMware.Vim.SharesInfo
$config.DeviceChange[2].Device.StorageIOAllocation.Shares.Shares = 1000
$config.DeviceChange[2].Device.StorageIOAllocation.Shares.Level = 'normal'
$config.DeviceChange[2].Device.StorageIOAllocation.Limit = -1
$config.DeviceChange[2].Device.Backing = New-Object VMware.Vim.VirtualDiskFlatVer2BackingInfo
$config.DeviceChange[2].Device.Backing.FileName = $datastore
$config.DeviceChange[2].Device.Backing.EagerlyScrub = $false
$config.DeviceChange[2].Device.Backing.ThinProvisioned = $true
$config.DeviceChange[2].Device.Backing.DiskMode = 'persistent'
$config.DeviceChange[2].Device.ControllerKey = -101
$config.DeviceChange[2].Device.UnitNumber = 0
$config.DeviceChange[2].Device.CapacityInKB = 16777216
$config.DeviceChange[2].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[2].Device.DeviceInfo.Summary = 'New Hard disk'
$config.DeviceChange[2].Device.DeviceInfo.Label = 'New Hard disk'
$config.DeviceChange[2].Device.Key = -102
$config.DeviceChange[2].Operation = 'add'

$pg = Get-VDPortGroup -Name $Portgroup

$config.DeviceChange[3] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[3].Device = New-Object VMware.Vim.VirtualVmxnet3
$config.DeviceChange[3].Device.MacAddress = ''
$config.DeviceChange[3].Device.ResourceAllocation = New-Object VMware.Vim.VirtualEthernetCardResourceAllocation
$config.DeviceChange[3].Device.ResourceAllocation.Limit = -1
$config.DeviceChange[3].Device.ResourceAllocation.Reservation = 0
$config.DeviceChange[3].Device.ResourceAllocation.Share = New-Object VMware.Vim.SharesInfo
$config.DeviceChange[3].Device.ResourceAllocation.Share.Shares = 50
$config.DeviceChange[3].Device.ResourceAllocation.Share.Level = 'normal'
$config.DeviceChange[3].Device.Connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$config.DeviceChange[3].Device.Connectable.Connected = $true
$config.DeviceChange[3].Device.Connectable.AllowGuestControl = $true
$config.DeviceChange[3].Device.Connectable.StartConnected = $true
$config.DeviceChange[3].Device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
$config.DeviceChange[3].Device.Backing.Port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
$config.DeviceChange[3].Device.Backing.Port.SwitchUuid = $pg.VirtualSwitch.ExtensionData.Uuid
$config.DeviceChange[3].Device.Backing.Port.PortgroupKey = $pg.Extensiondata.Key
$config.DeviceChange[3].Device.AddressType = 'generated'
$config.DeviceChange[3].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[3].Device.DeviceInfo.Summary = 'New Network'
$config.DeviceChange[3].Device.DeviceInfo.Label = 'New Network'
$config.DeviceChange[3].Device.Key = -103
$config.DeviceChange[3].Operation = 'add'


$config.DeviceChange[4] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[4].Device = New-Object VMware.Vim.VirtualCdrom
$config.DeviceChange[4].Device.Connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$config.DeviceChange[4].Device.Connectable.Connected = $false
$config.DeviceChange[4].Device.Connectable.AllowGuestControl = $true
$config.DeviceChange[4].Device.Connectable.StartConnected = $true
$config.DeviceChange[4].Device.Backing = New-Object VMware.Vim.VirtualCdromIsoBackingInfo
$config.DeviceChange[4].Device.Backing.FileName = $isofile
$config.DeviceChange[4].Device.ControllerKey = 200
$config.DeviceChange[4].Device.UnitNumber = 0
$config.DeviceChange[4].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[4].Device.DeviceInfo.Summary = 'New CD/DVD Drive'
$config.DeviceChange[4].Device.DeviceInfo.Label = 'New CD/DVD Drive'
$config.DeviceChange[4].Device.Key = -104
$config.DeviceChange[4].Operation = 'add'

$pg = Get-VDPortGroup -Name Dummy

$config.DeviceChange[5] = New-Object VMware.Vim.VirtualDeviceConfigSpec
$config.DeviceChange[5].Device = New-Object VMware.Vim.VirtualVmxnet3
$config.DeviceChange[5].Device.MacAddress = ''
$config.DeviceChange[5].Device.ResourceAllocation = New-Object VMware.Vim.VirtualEthernetCardResourceAllocation
$config.DeviceChange[5].Device.ResourceAllocation.Limit = -1
$config.DeviceChange[5].Device.ResourceAllocation.Reservation = 0
$config.DeviceChange[5].Device.ResourceAllocation.Share = New-Object VMware.Vim.SharesInfo
$config.DeviceChange[5].Device.ResourceAllocation.Share.Shares = 50
$config.DeviceChange[5].Device.ResourceAllocation.Share.Level = 'normal'
$config.DeviceChange[5].Device.Connectable = New-Object VMware.Vim.VirtualDeviceConnectInfo
$config.DeviceChange[5].Device.Connectable.Connected = $true
$config.DeviceChange[5].Device.Connectable.AllowGuestControl = $true
$config.DeviceChange[5].Device.Connectable.StartConnected = $true
$config.DeviceChange[5].Device.Backing = New-Object VMware.Vim.VirtualEthernetCardDistributedVirtualPortBackingInfo
$config.DeviceChange[5].Device.Backing.Port = New-Object VMware.Vim.DistributedVirtualSwitchPortConnection
$config.DeviceChange[5].Device.Backing.Port.SwitchUuid = $pg.VirtualSwitch.ExtensionData.Uuid
$config.DeviceChange[5].Device.Backing.Port.PortgroupKey = $pg.Extensiondata.Key
$config.DeviceChange[5].Device.AddressType = 'generated'
$config.DeviceChange[5].Device.DeviceInfo = New-Object VMware.Vim.Description
$config.DeviceChange[5].Device.DeviceInfo.Summary = 'New Network'
$config.DeviceChange[5].Device.DeviceInfo.Label = 'New Network'
$config.DeviceChange[5].Device.Key = -105
$config.DeviceChange[5].Operation = 'add'

$config.DeviceChange[5].Device.DeviceInfo.Label = 'New Network'
$config.DeviceChange[5].Device.Key = -105
$config.DeviceChange[5].Operation = 'add'

$config.FtEncryptionMode = 'ftEncryptionOpportunistic'
$config.MemoryReservationLockedToMax = $false
$config.SwapPlacement = 'inherit'
$config.Firmware = 'efi'
$config.GuestId = 'vmkernel65Guest'
$config.MaxMksConnections = 40
$config.Version = 'vmx-14'
$config.MemoryAllocation = New-Object VMware.Vim.ResourceAllocationInfo
$config.MemoryAllocation.Shares = New-Object VMware.Vim.SharesInfo
$config.MemoryAllocation.Shares.Shares = 983040
$config.MemoryAllocation.Shares.Level = 'normal'
$config.MemoryAllocation.Limit = -1
$config.MemoryAllocation.Reservation = 0
$config.NumCoresPerSocket = 4
$config.MigrateEncryption = 'opportunistic'
$config.Name = $templateVMName
$config.Files = New-Object VMware.Vim.VirtualMachineFileInfo
$config.Files.VmPathName = $datastore
$config.CpuAffinity = New-Object VMware.Vim.VirtualMachineAffinityInfo
$config.CpuAffinity.AffinitySet = New-Object int[] (0)
$config.PowerOpInfo = New-Object VMware.Vim.VirtualMachineDefaultPowerOpInfo
$config.PowerOpInfo.SuspendType = 'preset'
$config.PowerOpInfo.StandbyAction = 'checkpoint'
$config.PowerOpInfo.ResetType = 'preset'
$config.PowerOpInfo.PowerOffType = 'preset'

$ResPool = Get-View -viewtype ResourcePool -filter @{“Name”=$resourcePool}
$pool = $ResPool.MoRef
 
$_this =  Get-View -viewtype Folder -filter @{“Name”=$folderName} 
$_this.CreateVM_Task($config, $pool, $null)

Write-Host "Sleep 30"
Start-Sleep -Seconds 30

Write-Host "Starting VM : '$($templateVMName)'"

$vm=get-vm -Name $templateVMName
Start-VM $vm 

#####
Disconnect-VIServer -Confirm:$false