#Create vApp
#bdereims@vmware.com

$Vc = "###VCENTER###"
$vcUser = "###VCENTER_ADMIN###"
$vcPass = '###VCENTER_PASSWD###'
$Datacenter = "###VCENTER_DATACENTER###"
$Cluster = "###VCENTER_CLUSTER###"

Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false -DefaultVIServerMode multiple | out-null 
Connect-VIServer -Server $Vc -User $vcUser -Password $vcPass | out-null

Foreach ( $vAPP in Get-VApp -Location ( Get-Cluster -Name $Cluster ) | Where {$_.name -match "cPod-*"}  ) {
	Write-Host "$vAPP"
	Foreach ( $VM in Get-VM -Location ( Get-VApp -Name $vAPP ) ) {
		Write-Host "-- $VM"
	}	
}

Disconnect-VIServer -Confirm:$false
