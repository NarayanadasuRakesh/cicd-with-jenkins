pipeline {
    agent {
        node { label 'node1' }
    }
    parameters {
        string(name: 'version', defaultValue: '', description: 'What is the artifact version')
        string(name: 'environment', defaultValue: '', description: 'What is environment')
    }
    options {
        ansiColor('xterm')
        disableConcurrentBuilds()
    }
    stages {
        stage('Print version') {
            steps {
                sh """
                    echo "Version: ${params.version}"
                    echo "Environment: ${params.environment}"
                """
            }
        }
        stage('Init') {
            steps {
                sh """
                    cd terraform
                    terraform init --backend-config=${params.environment}/backend.tf -reconfigure
                """
            }
        }
        stage('Plan') {
            steps {
                sh """
                    cd terraform
                    terraform plan -var-file=${params.environment}/${params.environment}.tfvars -var="app_version=${params.version}"
                """
            }
        }
        stage('Apply') {
            steps {
                sh """
                    cd terraform
                    terraform apply -var-file=${params.environment}/${params.environment}.tfvars -var="app_version=${params.version}" -auto-approve
                """
            }
        }
        /*stage('Destroy') {
            steps {
                sh """
                    cd terraform
                    terraform destroy -var-file=${params.environment}/${params.environment}.tfvars -var="app_version=${params.version}" -auto-approve
                """
            }
        }*/
    }
}