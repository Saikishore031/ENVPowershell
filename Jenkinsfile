pipeline {
    agent any
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
                pwsh """
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
