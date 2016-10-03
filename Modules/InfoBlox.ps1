

# This function is from: http://sharpcodenotes.blogspot.nl/2013/03/how-to-make-http-request-with-powershell.html
function Http-Web-Request([string]$method,[string]$encoding,[string]$server,[string]$path,$headers,[string]$postData)
{
  $return_value = New-Object PsObject -Property @{httpCode = ""; httpResponse = ""}

  ## Compose the URL and create the request
  $url = "$server/$path"
  [System.Net.HttpWebRequest] $request = [System.Net.HttpWebRequest] [System.Net.WebRequest]::Create($url)

  ## Add the method (GET, POST, etc.)
  $request.Method = $method
  ## Add an headers to the request
  foreach($key in $headers.keys)
  {
    $request.Headers.Add($key, $headers[$key])
  }

  ## We are using $encoding for the request as well as the expected response
  $request.Accept = $encoding
  ## Send a custom user agent if you want
  $request.UserAgent = "PowerShell script"

  ## Create the request body if the verb accepts it (NOTE: utf-8 is assumed here)
  if ($method -eq "POST" -or $method -eq "PUT") {
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($postData)
    $request.ContentType = $encoding
    $request.ContentLength = $bytes.Length

    [System.IO.Stream] $outputStream = [System.IO.Stream]$request.GetRequestStream()
    $outputStream.Write($bytes,0,$bytes.Length)
    $outputStream.Close()
  }

  ## This is where we actually make the call.
  try
  {
    [System.Net.HttpWebResponse] $response = [System.Net.HttpWebResponse] $request.GetResponse()
    $sr = New-Object System.IO.StreamReader($response.GetResponseStream())
    $txt = $sr.ReadToEnd()
    ## NOTE: comment out the next line if you don't want this function to print to the terminal
    #Write-Host "CONTENT-TYPE: " $response.ContentType
    ## NOTE: comment out the next line if you don't want this function to print to the terminal
    #Write-Host "RAW RESPONSE DATA:" . $txt
    ## Return the response body to the caller
    $return_value.httpResponse = $txt
    $return_value.httpCode = [int]$response.StatusCode

    return $return_value
  }
  ## This catches errors from the server (404, 500, 501, etc.)
  catch [Net.WebException] {
    [System.Net.HttpWebResponse] $resp = [System.Net.HttpWebResponse] $_.Exception.Response
    ## NOTE: comment out the next line if you don't want this function to print to the terminal
    #Write-Host $resp.StatusCode -ForegroundColor Red -BackgroundColor Yellow
    ## NOTE: comment out the next line if you don't want this function to print to the terminal
    #Write-Host $resp.StatusDescription -ForegroundColor Red -BackgroundColor Yellow
    ## Return the error to the caller
    $return_value.httpResponse = $resp.StatusDescription
    $return_value.httpCode = [int]$resp.StatusCode

    return $return_value
  }
}

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

  # Form authentication header
  $auth    = [System.Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($Username + ":" + $Password))
  $headers = @{ Authorization = "Basic $auth" }

  #####
  ##### Get DHCP lease first
  #####

  # Form the URL to the InfoBlox API
  $URL = "/wapi/v2.3.1/lease?address~=" + $IP_Address + "&_return_fields=address,binding_state,hardware,discovered_data&_paging=1&_max_results=1&_return_as_object=1"
  $Infoblox_URL = "https://" + $IPAM_Address

  # Fire off REST request
  $result = Http-Web-Request "GET" "application/xml" $Infoblox_URL $URL $headers ""

  # Check HTTP return code
  if($result.httpCode -ne 200) {
    return $False
  }

  # Convert returning text to XML
  [xml]$result_xml = $result.httpResponse

  # Check if there's even a result returned
  if($result_xml.value.result.list -eq "")
  {
    #####
    ##### No DHCP Lease? Check fixed hosts
    #####

    # Form the URL to the InfoBlox API
    $URL = "/wapi/v2.3.1/record:host?ipv4addr~=" + $IP_Address + "&_max_results=1&_return_as_object=1"
    $Infoblox_URL = "https://" + $IPAM_Address

    # Fire off REST request
    $result_fixed = Http-Web-Request "GET" "application/xml" $Infoblox_URL $URL $headers ""

    # Check HTTP return code
    if($result_fixed.httpCode -ne 200) {
      return $False
    }

    # Convert returning text to XML
    [xml]$result_xml_fixed = $result_fixed.httpResponse

    # Check if there's even a result returned
    if($result_xml_fixed.value.result.list.value -eq "") {
      return $False
    }

    $found_fixed = $True

    # Put the returned results that we need in easy to use variables
    $ipam_ip    = $result_xml_fixed.value.result.list.value.ipv4addrs.list.value.ipv4addr
    $ipam_mac   = $result_xml_fixed.value.result.list.value.ipv4addrs.list.value.mac

    # This one would be a weird one; but does the IP address match the one we're looking for?
    if($ipam_ip -ne $IP_Address) {
      $found_fixed = $False
    }

    # Check if the MAC address is as expected
    if($ipam_mac -ne $MAC_Address) {
      $found_fixed = $False
    }

    return $found_fixed
  }

  # Put the returned results that we need in easy to use variables
  $ipam_ip    = $result_xml.value.result.list.value.address
  $ipam_mac   = $result_xml.value.result.list.value.hardware
  $ipam_state = $result_xml.value.result.list.value.binding_state

  # Is the binding active? Other possibilities are "FREE" and "INACTIVE"
  if($ipam_state -ne "ACTIVE") {
    return $False
  }

  # This one would be a weird one; but does the IP address match the one we're looking for?
  if($ipam_ip -ne $IP_Address) {
    return $False
  }

  # Check if the MAC address is as expected
  if($ipam_mac -ne $MAC_Address) {
    return $False
  }

  # All tests have succeeded, approve IP & MAC binding!
  return $True
}
