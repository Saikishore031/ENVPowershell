# Function to create and configure a VM
<#
param (
    [string]$vmName  # Only the VM name will be passed as a parameter
)
#>
# Ensure VMware PowerCLI module is installed and imported
if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
    Install-Module -Name VMware.PowerCLI -Force -AllowClobber
}
Import-Module VMware.PowerCLI
Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:$false 
# Connect to vCenter server
$vcenterServer = "172.16.8.20"
$vcUser = "dsmsv@vsphere.local"
$vcPass = "Hitachi_DS.2024"
$domainpassword = "Hitachi1@3" | ConvertTo-SecureString -asPlainText -Force
$domainusername = "envhit.local\administrator"
$credential = New-Object System.Management.Automation.PSCredential($domainusername, $domainpassword)
$domain = "envhit.local"
Connect-VIServer -Server $vcenterServer -User $vcUser -Password $vcPass 

$vmName = "saitest09"
$ipAddress = "172.16.8.251"
# Define VM parameters
$vmHost = "hcusdenvsp06.hitachiconsulting.net"      # ESXi host name
$datastore = "SN005_442910_DS-MSV_050A"             # Datastore for VM files
$networkName = "DS_MSV_VM_VLAN8"                    # Network name
$subnetMask = "255.255.255.0"
$gateway = "172.16.8.1"
$dns = "172.16.8.186"
echo $vmName
# Create the VM
Write-Host "Creating new VM: $vmName"
New-VM -Name $vmName -VMHost $vmHost -Template "win2019" -Datastore $datastore -NetworkName $networkName 
Start-Sleep -Seconds 30

# Power on the VM
Write-Host "Powering on VM: $vmName"
Start-VM -VM $vmName -RunAsync 

# Set static IP address and hostname using VMware Tools (Invoke-VMScript)
$guestUsername = "administrator"  # Admin username within the guest OS
$guestPassword = "Hitachi1@3"     # Admin password within the guest OS

Connect-VIServer -Server "172.16.8.236" -User root -Password "Hitachi1!" 
Write-Host "Connecting to vCenter server..."

Write-Host "Assigning the IP address..."
# Set the IP address (assumes the VM is running Windows)
$ipConfigScript = @"
New-NetIPAddress -InterfaceAlias 'Ethernet0' -IPAddress '$ipAddress' -PrefixLength 24 -DefaultGateway '$gateway'
Set-DnsClientServerAddress -InterfaceAlias 'Ethernet0' -ServerAddresses ('$dns')
"@

# Invoke the script on the guest OS
Invoke-VMScript -VM $vmName -ScriptText $ipConfigScript -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue  
Start-Sleep -Seconds 30
Write-Host "IP address assigned to VM: $ipAddress"

# Define unattend.xml content for Sysprep
$unattendXML = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="oobeSystem">
        <component name="Microsoft-Windows-International-Core" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <InputLocale>en-us</InputLocale>
            <SystemLocale>en-us</SystemLocale>
            <UILanguage>en-us</UILanguage>
            <UserLocale>en-us</UserLocale>
        </component>
        <component name="Microsoft-Windows-Shell-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <OOBE>
                <HideEULAPage>true</HideEULAPage>
            </OOBE>
            <UserAccounts>
                <AdministratorPassword>
                    <Value>Hitachi1@3</Value>
                    <PlainText>true</PlainText>
                </AdministratorPassword>
            </UserAccounts>
            <AutoLogon>
                <Username>Administrator</Username>
                <Password>
                    <Value>Hitachi1@3</Value>
                    <PlainText>true</PlainText>
                </Password>
                <Enabled>true</Enabled>
            </AutoLogon>
            <FirstLogonCommands>
                <SynchronousCommand wcm:action="add">
                    <CommandLine>cmd /c echo First logon commands executed</CommandLine>
                    <Order>1</Order>
                </SynchronousCommand>
            </FirstLogonCommands>
        </component>
    </settings>
</unattend>
"@

$unattendPath = "C:\Windows\unattend.xml"
$sysprepScript = @"
Set-Content -Path '$unattendPath' -Value '$unattendXML' -Force
"@

# Copy the unattend.xml to the VM
Invoke-VMScript -VM $vmName -ScriptText $sysprepScript -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue  

# Run Sysprep on the guest VM
$sysprepCommand = "C:\Windows\System32\Sysprep\Sysprep.exe /generalize /oobe /reboot /unattend:$unattendPath"
Invoke-VMScript -VM $vmName -ScriptText $sysprepCommand -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue  

Write-Host "Running Sysprep..."
Start-Sleep -Seconds 120
write-host "Sysprep completed..."
Start-Sleep -Seconds 30
write-host "Waiting for server to be online..."


$domainjoin = @"
Rename-Computer -NewName $vmName
Add-Computer -DomainName '$domain' -Credential (New-Object PSCredential('envhit.local\administrator', (ConvertTo-SecureString 'Hitachi1@3' -AsPlainText -Force)))
"@

Invoke-VMScript -VM $vmName -ScriptText $domainjoin -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue 
start-sleep -Seconds 20
Write-Host "VM added to domain: $domain"



$rename = @"
Rename-Computer -NewName "$vmName"
"@

Invoke-VMScript -VM $vmName -ScriptText $rename -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue 
start-sleep -Seconds 20
Write-Host "VM added to domain: $domain"

# Join the VM to the domain
$Restart = @"
Restart-Computer -Force
"@

Invoke-VMScript -VM $vmName -ScriptText $Restart -GuestUser $guestUsername -GuestPassword $guestPassword -ScriptType Powershell -ErrorAction SilentlyContinue  

# Output VM information
$vmInfo = Get-VM -Name $vmName
$vmInfo | Select-Object Name, @{Name="IP Address";Expression={$_.Guest.IPAddress}}, @{Name="Hostname";Expression={$_.Guest.HostName}}

Write-Host "VM $vmName deployed with IP $ipAddress and hostname:$vmName"
