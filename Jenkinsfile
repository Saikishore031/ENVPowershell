pipeline {
    agent any

    environment {
        // Fetch credentials securely from Jenkins credentials store
        VCENTER_USER = "dsmsv@vsphere.local"
        VCENTER_PASS = "Hitachi_DS.2024"
        DOMAIN_USER = "administrator"
        DOMAIN_PASS = "Hitachi1@3"
        VCENTER_SERVER = "172.16.8.20"
        GUEST_USER = "administrator"
        GUEST_PASS = "Hitachi1@3"
        VM_NAME = "saitest08"
        VM_HOST = "hcusdenvsp06.hitachiconsulting.net"
        DATASTORE = "SN005_442910_DS-MSV_050A"
        NETWORK_NAME = "DS_MSV_VM_VLAN8"
        IP_ADDRESS = "172.16.8.253"
        SUBNET_MASK = "255.255.255.0"
        GATEWAY = "172.16.8.1"
        DNS = "172.16.8.186"
        DOMAIN = "envhit.local"
    }

    stages {
        stage('Install PowerCLI and Import Modules') {
            steps {
                powershell """
                if (-not (Get-Module -ListAvailable -Name VMware.PowerCLI)) {
                    Install-Module -Name VMware.PowerCLI -Force -AllowClobber
                }
                Import-Module VMware.PowerCLI
                Set-PowerCLIConfiguration -InvalidCertificateAction Ignore -Confirm:\$false
                """
            }
        }

        stage('Connect to vCenter Server') {
            steps {
                powershell """
                Connect-VIServer -Server ${VCENTER_SERVER} -User ${VCENTER_USER} -Password ${VCENTER_PASS}
                """
            }
        }

        stage('Create and Configure VM') {
            steps {
                powershell """
                Write-Host "Creating new VM: ${VM_NAME}"
                New-VM -Name ${VM_NAME} -VMHost ${VM_HOST} -Template "win2019" -Datastore ${DATASTORE} -NetworkName ${NETWORK_NAME}
                Start-VM -VM ${VM_NAME} -RunAsync
                Start-Sleep -Seconds 30
                """
            }
        }

        stage('Assign Static IP') {
            steps {
                powershell """
                \$ipConfigScript = @"
                New-NetIPAddress -InterfaceAlias 'Ethernet0' -IPAddress '${IP_ADDRESS}' -PrefixLength 24 -DefaultGateway '${GATEWAY}'
                Set-DnsClientServerAddress -InterfaceAlias 'Ethernet0' -ServerAddresses ('${DNS}')
                "@

                Invoke-VMScript -VM ${VM_NAME} -ScriptText \$ipConfigScript -GuestUser ${GUEST_USER} -GuestPassword ${GUEST_PASS} -ScriptType Powershell -ErrorAction SilentlyContinue
                Start-Sleep -Seconds 30
                """
            }
        }

        stage('Run Sysprep and Configure Unattend.xml') {
            steps {
                powershell """
                \$unattendXML = @"
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
                                    <Value>${GUEST_PASS}</Value>
                                    <PlainText>true</PlainText>
                                </AdministratorPassword>
                            </UserAccounts>
                        </component>
                    </settings>
                </unattend>
                "@

                \$unattendPath = "C:\\Windows\\unattend.xml"
                \$sysprepScript = @"
                Set-Content -Path '\$unattendPath' -Value '\$unattendXML' -Force
                "@

                Invoke-VMScript -VM ${VM_NAME} -ScriptText \$sysprepScript -GuestUser ${GUEST_USER} -GuestPassword ${GUEST_PASS} -ScriptType Powershell -ErrorAction SilentlyContinue  
                Invoke-VMScript -VM ${VM_NAME} -ScriptText "C:\\Windows\\System32\\Sysprep\\Sysprep.exe /generalize /oobe /reboot /unattend:\$unattendPath" -GuestUser ${GUEST_USER} -GuestPassword ${GUEST_PASS} -ScriptType Powershell -ErrorAction SilentlyContinue  
                Start-Sleep -Seconds 120
                """
            }
        }

        stage('Join VM to Domain') {
            steps {
                powershell """
                \$domainjoin = @"
                Rename-Computer -NewName ${VM_NAME}
                Add-Computer -DomainName '${DOMAIN}' -Credential (New-Object PSCredential('${DOMAIN_USER}', (ConvertTo-SecureString '${DOMAIN_PASS}' -AsPlainText -Force)))
                "@

                Invoke-VMScript -VM ${VM_NAME} -ScriptText \$domainjoin -GuestUser ${GUEST_USER} -GuestPassword ${GUEST_PASS} -ScriptType Powershell -ErrorAction SilentlyContinue  
                Restart-VM -VM ${VM_NAME} -Confirm:\$false
                """
            }
        }

        stage('VM Info') {
            steps {
                powershell """
                \$vmInfo = Get-VM -Name ${VM_NAME}
                \$vmInfo | Select-Object Name, @{Name="IP Address";Expression={\$_..Guest.IPAddress}}, @{Name="Hostname";Expression={\$_..Guest.HostName}}
                """
            }
        }
    }
    
    post {
        always {
            echo "Cleanup or final steps if needed"
        }
    }
}
