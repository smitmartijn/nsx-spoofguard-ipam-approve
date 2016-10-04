# nsx-spoofguard-ipam-approve
NSX Spoofguard IPAM Approvals


# nsx-spoofguard-approve.ps1

The Spoofguard function in NSX can block VMs from using unauthorized IP addresses on the network. With the proper policy, network admins would need to approve the use of the IP address before a VM is allowed to use it.

This script can query your IPAM system and check whether to approve NSX Spoofguard records. If the IPAM currently has a DHCP or static record for the VMs IP address and MAC address, it approves it inside NSX.

```
Usage: .\NSX-Spoofguard-Approve.ps1
   -NSX_Manager_IP       - IP or hostname of the NSX Manager
   -NSX_Manager_User     - Username for the login to the NSX Manager
   -NSX_Manager_Password - Password for the login to the NSX Manager
   -VC_User              - Username for the login to the vCenter connected to the NSX Manager
   -VC_Password          - Password for the login to the vCenter connected to the NSX Manager
   -SpoofGuardPolicy     - Name of the Spoofguard policy that we're using
   -IPAM_IP              - IP or hostname of the IPAM Manager
   -IPAM_User            - Username for the login to the IPAM Manager
   -IPAM_Password        - Password for the login to the IPAM Manager
   -IPAM_Module          - What IPAM module are we using? (Currently: Infoblox, ApproveAll)
```

# Example:

```
PowerCLI > .\Install-NSX.ps1 -NSX_Manager_IP nsx-manager -NSX_Manager_User admin -NSX_Manager_Password passwd -VC_User administrator@vsphere.local -VC_Password passwd
                             -SpoofGuardPolicy approve-all -IPAM_IP infoblox-manager -IPAM_User admin -IPAM_Password passwd -IPAM_Module Infoblox
```

# ChangeLog:

03-10-2016 - Martijn Smit <martijn@lostdomain.org>
 - Initial script
