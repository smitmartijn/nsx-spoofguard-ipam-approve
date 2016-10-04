#
# nsx-spoofguard-approve.ps1
#
# The Spoofguard function in NSX can block VMs from using unauthorized IP addresses on the network. With the proper policy,
# network admins would need to approve the use of the IP address before a VM is allowed to use it.
#
# This script can query your IPAM system and check whether to approve NSX Spoofguard records. If the IPAM currently
# has a DHCP or static record for the VMs IP address and MAC address, it approves it inside NSX.
#
# Usage: .\NSX-Spoofguard-Approve.ps1
#   -NSX_Manager_IP       - IP or hostname of the NSX Manager
#   -NSX_Manager_User     - Username for the login to the NSX Manager
#   -NSX_Manager_Password - Password for the login to the NSX Manager
#   -VC_User              - Username for the login to the vCenter connected to the NSX Manager
#   -VC_Password          - Password for the login to the vCenter connected to the NSX Manager
#   -SpoofGuardPolicy     - Name of the Spoofguard policy that we're using
#   -IPAM_IP              - IP or hostname of the IPAM Manager
#   -IPAM_User            - Username for the login to the IPAM Manager
#   -IPAM_Password        - Password for the login to the IPAM Manager
#   -IPAM_Module          - What IPAM module are we using? (Currently: Infoblox, ApproveAll)
#
# Example:
#
# PowerCLI > .\Install-NSX.ps1 -NSX_Manager_IP nsx-manager -NSX_Manager_User admin -NSX_Manager_Password passwd -VC_User administrator@vsphere.local -VC_Password passwd
#                              -SpoofGuardPolicy approve-all -IPAM_IP infoblox-manager -IPAM_User admin -IPAM_Password passwd -IPAM_Module Infoblox
#
# ChangeLog:
#
# 03-10-2016 - Martijn Smit <martijn@lostdomain.org>
# - Initial script
#
#

param (
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$NSX_Manager_IP,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$NSX_Manager_User,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$NSX_Manager_Password,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$VC_User,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$VC_Password,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$SpoofGuardPolicy,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$IPAM_IP,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$IPAM_User,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$IPAM_Password,
  [parameter(Mandatory=$true, ValueFromPipeLine=$true, ValueFromPipeLineByPropertyName=$true)]
  [ValidateNotNullOrEmpty()]
  [string]$IPAM_Module
)

# Load PowerCLI
if (!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
  if (Test-Path -Path 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI' ) {
    $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\WOW6432Node\VMware, Inc.\VMware vSphere PowerCLI'
  }
  else {
    $Regkey = 'Registry::HKEY_LOCAL_MACHINE\SOFTWARE\VMware, Inc.\VMware vSphere PowerCLI'
  }
  .(join-path -path (Get-ItemProperty  $Regkey).InstallPath -childpath 'Scripts\Initialize-PowerCLIEnvironment.ps1')
}
if (!(Get-Module -Name VMware.VimAutomation.Core -ErrorAction SilentlyContinue)) {
  Write-Host "VMware modules not loaded/unable to load"
  Exit
}

# Load PowerNSX
Import-Module -Name '.\PowerNSX.psm1' -ErrorAction SilentlyContinue -DisableNameChecking

# Load IPAM approver module
$IPAM_ModulePath = (".\Modules\" + $IPAM_Module + ".ps1")
if (!(Test-Path $IPAM_ModulePath)) {
  Write-Host "IPAM Module '$IPAM_ModulePath' not found!" -ForegroundColor "red"
  Exit
}

Import-Module $IPAM_ModulePath

# Connect to NSX Manager
if(!(Connect-NSXServer -Server $NSX_Manager_IP -Username $NSX_Manager_User -Password $NSX_Manager_Password -VIUserName $VC_User -VIPassword $VC_Password)) {
  Write-Host "Unable to connect to NSX Manager!" -ForegroundColor "red"
  Exit
}

$need_approval = (Get-NsxSpoofguardPolicy -Name $SpoofGuardPolicy | Get-NsxSpoofguardNic -Filter Inactive)

# Initialise counters
$records_found  = 0
$records_denied = 0
$records_approved = 0

foreach($record in $need_approval)
{
  $ips = $record.detectedIpAddress.IpAddress.Split(" ")
  $mac = $record.detectedMacAddress
  foreach($ip in $ips)
  {
    if($ip.StartsWith("fe80:")) {
      # Skip IPv6 local addresses
      Continue
    }

    $records_found++

    $vm = Get-VM -Id ("VirtualMachine-" + $record.vmMoid)
    $nic = $record.nicName.TrimStart($vm.Name + " - ")

    $approved = Get-IPAMApproval -IPAM_Address $IPAM_IP -Username $IPAM_User -Password $IPAM_Password -IP_Address $ip -MAC_Address $mac

    if($approved -eq $True) {
      $publish = Get-NsxSpoofguardPolicy $SpoofGuardPolicy | Get-NsxSpoofguardNic -NetworkAdapter ($vm | Get-NetworkAdapter -Name $nic) | Grant-NsxSpoofguardNicApproval -IpAddress $ip -Publish
      Write-Host -ForegroundColor green "IP Address $ip with MAC $mac approved by IPAM, activating it in NSX SpoofGuard!"
      $records_approved++
    }
    else {
      Write-Host -ForegroundColor red "IP Address $ip with MAC $mac declined!"
      $records_denied++
    }
  }
}

Write-Host "Found $records_found Spoofguard records; approved $records_approved and denied $records_denied"
