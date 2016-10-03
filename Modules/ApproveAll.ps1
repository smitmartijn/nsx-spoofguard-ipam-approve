
function Get-IPAMApproval
{
  [CmdletBinding()]

  param(
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$IPAM_Address,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$Username,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$Password,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$IP_Address,
    [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
    [string]$MAC_Address
  )

  # Approve all request!
  return $True
}
