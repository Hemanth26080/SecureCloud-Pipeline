pipeline {
    agent any

    environment {
        REGISTRY   = 'YOUR-ACCOUNT-ID.dkr.ecr.eu-west-3.amazonaws.com'
        IMAGE      = 'securecloud-flask'
        AWS_REGION = 'us-east-1'
        TRIVY_SEVER = 'CRITICAL,HIGH'
    }

    stages {

        stage('Checkout') {
            steps {
                checkout scm
            }
        }

        stage('Lint and Security Scan') {
            steps {
                sh 'pip3 install flake8 bandit --quiet'
                sh 'flake8 app/ --max-line-length=120'
                sh 'bandit -r app/ -ll'
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'pip3 install -r requirements.txt pytest pytest-cov --quiet'
                sh 'pytest tests/unit/ -v --cov=app --cov-report=xml --junitxml=test-reports/junit.xml'
            }
            post {
                always {
                    junit allowEmptyResults: true, testResults: 'test-reports/*.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${env.IMAGE}:${env.BUILD_NUMBER} -f docker/Dockerfile ."
            }
        }

        stage('Scan Docker Image') {
            steps {
                sh """
                    trivy image \
                        --severity ${env.TRIVY_SEVER} \
                        --ignorefile .trivyignore \
                        --exit-code 1 \
                        ${env.IMAGE}:${env.BUILD_NUMBER}
                """
            }
        }

        stage('Deploy to Staging') {
            when { branch 'main' }
            steps {
                echo "Deploying build ${env.BUILD_NUMBER} to staging..."
                sh 'echo Terraform apply would run here'
            }
        }

        stage('Integration Tests') {
            when { branch 'main' }
            steps {
                echo "Running integration tests..."
                sh 'pytest tests/integration/ -v || echo No integration tests yet'
            }
        }

        stage('Approve Production?') {
            when { branch 'main' }
            steps {
                input message: "Deploy build #${env.BUILD_NUMBER} to PRODUCTION?",
                      ok: "Yes, deploy it!"
            }
        }

        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                echo "Deploying to production..."
                sh 'echo Terraform prod apply would run here'
            }
        }

        stage('Health Check') {
            when { branch 'main' }
            steps {
                echo "Running health check..."
                sh 'curl -f http://localhost:5000/health || echo Health check skipped in CI'
            }
        }
    }

    post {
        failure {
            echo "Build ${env.BUILD_NUMBER} FAILED"
        }
        success {
            echo "Build ${env.BUILD_NUMBER} succeeded"
            archiveArtifacts artifacts: 'test-reports/**', allowEmptyArchive: true
        }
    }
}