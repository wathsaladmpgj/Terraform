pipeline {
  agent any

  stages {
    stage('Check Repo') {
      steps {
        sh 'echo Jenkinsfile found!'
        sh 'ls -la'
      }
    }

    stage('Terraform Init') {
      steps {
        sh 'terraform init'
      }
    }

    stage('Terraform Plan') {
      steps {
        sh 'terraform plan'
      }
    }
  }
}
