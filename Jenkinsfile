pipeline {
    agent any

    environment {
        vcenterServer = "172.16.8.20"
        vcUser = "dsmsv@vsphere.local"
        vcPass = "Hitachi_DS.2024"
        domainusername = "envhit.local\administrator"
        domainpassword = "Hitachi1@3"
    }

    stages {
        stage('Checkout PowerShell Script') {
            steps {
                // If your script is in a Git repository
                git branch: 'main', url: 'https://github.com/Saikishore031/ENVPowershell.git'
            }
        }

        stage('Run PowerShell Script') {
            steps {
                // Assuming the PowerShell script is in the workspace directory
                powershell """
                # Call the script
                ./vm-creation-script.ps1
                """
            }
        }
    }

    post {
        always {
            echo "PowerShell script execution completed."
        }
    }
}
