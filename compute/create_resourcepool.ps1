#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"
$Portgroup = "###PORTGROUP###"
$oldNet = "Dummy"
$cPodName = "###CPOD_NAME###"
$templateVM = "###TEMPLATE_VM###"
$templateESX = "###TEMPLATE_ESX###"
$IP = "###IP###"
$rootPasswd = "###ROOT_PASSWD###"
$Datastore = "###DATASTORE###"
$numberESX = ###NUMESX###
$rootDomain = "###ROOT_DOMAIN###"
$asn = "###ASN###"
$owner = "###OWNER###"
$startNumESX = ###STARTNUMESX###

$OwnerTag = "cPodOwner"
$CreateTag = "cPodCreateDate"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass

##### Tag Management

### Owner

$test = Get-TagCategory |  Where {$_.Name -eq $OwnerTag}
if ( $test -eq $null ) {
	New-TagCategory -Name $OwnerTag -Description "cPod Owner in order to manage resources consumption"
} 

$test = Get-Tag | Where {$_.Name -eq $owner}
if ( $test -eq $null ) {
	Get-TagCategory -Name $OwnerTag | New-Tag -Name $owner 
}
$OwnerTag = Get-Tag $owner 

### CreateDate

$test = Get-TagCategory |  Where {$_.Name -eq $CreateTag}
if ( $test -eq $null ) {
        New-TagCategory -Name $CreateTag -Description "cPod Create Date in order to manage resources consumption"
}
$createdate = Get-Date -UFormat "%m/%d/%Y-%R"
$test = Get-Tag | Where {$_.Name -eq $createdate}
if ( $test -eq $null ) {
	Get-TagCategory -Name $CreateTag | New-Tag -Name $createdate
}
$CreateTag = Get-Tag $createdate

#####
# Fresh cPod or adding esx to an existing one
if ( $startNumESX -eq 1 ) {

Write-Host "Create/modifying RessourcePool."
#$ResPool = New-ResourcePool -Name cPod-$cPodName -MemLimitGB 96 -Location ( Get-Cluster -Name $Cluster ) 
$ResPool = New-ResourcePool -Name cPod-$cPodName -Location ( Get-ResourcePool -Name cPod-Workload ) 
$ResPool | New-TagAssignment -Tag $OwnerTag
$ResPool | New-TagAssignment -Tag $CreateTag

Write-Host "Add cPodRouter VM."
$CpodRouter = New-VM -Name cPod-$cPodName-cpodrouter -VM $templateVM -ResourcePool $ResPool -Datastore $Datastore
$CpodRouter | New-TagAssignment -Tag $OwnerTag
$CpodRouter | New-TagAssignment -Tag $CreateTag

Write-Host "Add Disk for /data in cPodRouter."
# vSAN optimized with multiple components based on vSAN 6.7 chunk of 255GB :  6x255 = 1530Gb
For ($i=1; $i -le 6; $i++) {
	$CpodRouter | New-HardDisk -StorageFormat Thin -CapacityGB 255
}

Write-Host "Modify cPodRouter vNIC."
Get-NetworkAdapter -VM $CpodRouter | Where {$_.NetworkName -eq $oldNet } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name $Portgroup ) -Confirm:$false

Start-VM -VM $CpodRouter -Confirm:$false 
Start-Sleep -s 5 

Write-Host "Launch Update script in the cPod context."
Invoke-VMScript -VM $CpodRouter -ScriptText "cd update ; ./update.sh $cPodName $IP $rootDomain $asn ; sync ; reboot" -GuestUser root -GuestPassword $rootPasswd -scripttype Bash -ToolsWaitSecs 20 -RunAsync
if ($numberESX -lt 2) {
	Start-Sleep -s 20 
}

}
#####

# Retrieve ResPool in case of adding ESX to existing one
if ( $startNumESX -gt 1 ) {
	$ResPool = Get-ResourcePool -Name cPod-$cPodName -Location ( Get-ResourcePool -Name cPod-Workload )
	$LASTESX=$startNumESX+$numberESX-1
}
else {
	$LASTESX=$numberESX
}

Write-Host "Add " $numberESX " ESX VMs starting with" $startNumESX " to "$LASTESX
For ($i=$startNumESX; $i -le $LASTESX; $i++) {
	$ESXNUMBER="{0:d2}" -f $i
	Write-Host "-> cPod-$cPodName-esx$ESXNUMBER"
	$ESXVM = New-VM -Name cPod-$cPodName-esx$ESXNUMBER -VM $templateESX -ResourcePool $ResPool -Datastore $Datastore
	$ESXVM | New-TagAssignment -Tag $OwnerTag
	$ESXVM | New-TagAssignment -Tag $CreateTag

	# Adding Disk(s) for vVsan
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 128
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 128
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 512
	$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 512

	# Local Datastore for VCSA
	#$ESXVM | New-HardDisk -StorageFormat Thin -CapacityGB 50 
	
	Get-NetworkAdapter -VM $ESXVM | Where {$_.NetworkName -eq $oldNet } | Set-NetworkAdapter -Portgroup ( Get-VDPortGroup -Name $Portgroup ) -Confirm:$false

	Start-VM -VM cPod-$cPodName-esx$ESXNUMBER -Confirm:$false
}

#####

Disconnect-VIServer -Confirm:$false
