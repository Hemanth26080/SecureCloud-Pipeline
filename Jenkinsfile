pipeline {
    agent { label 'docker' }

    environment {
        REGISTRY    = 'YOUR-ACCOUNT-ID.dkr.ecr.eu-west-3.amazonaws.com'
        IMAGE       = 'securecloud-flask'
        AWS_REGION  = 'eu-west-3'
        TRIVY_SEVER = 'CRITICAL,HIGH'
    }

    stages {

        stage('Checkout') {
            steps {
                git branch: 'main',
                    url: 'https://github.com/YOUR-USERNAME/SecureCloud-Flask'
            }
        }

        stage('Lint & Security Scan Code') {
            steps {
                sh 'pip3 install flake8 bandit'
                sh 'flake8 app/ --max-line-length=120'    // Style check
                sh 'bandit -r app/ -ll'                   // Security check Python code
            }
        }

        stage('Unit Tests') {
            steps {
                sh 'pip3 install -r requirements.txt pytest pytest-cov'
                sh 'pytest tests/unit/ -v --cov=app --cov-report=xml --junitxml=test-reports/junit.xml'
            }
            post {
                always {
                    junit 'test-reports/*.xml'             // Show test results in Jenkins
                    cobertura coberturaReportFile: 'coverage.xml'
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh "docker build -t ${REGISTRY}/${IMAGE}:${BUILD_NUMBER} -f docker/Dockerfile ."
                sh "docker tag ${REGISTRY}/${IMAGE}:${BUILD_NUMBER} ${REGISTRY}/${IMAGE}:latest"
            }
        }

        stage('Scan Docker Image') {
            steps {
                sh """
                    trivy image \
                        --severity ${TRIVY_SEVER} \
                        --exit-code 1 \
                        --format table \
                        ${REGISTRY}/${IMAGE}:${BUILD_NUMBER}
                """
            }
        }

        stage('Push to ECR') {
            steps {
                sh """
                    aws ecr get-login-password --region ${AWS_REGION} | \
                    docker login --username AWS --password-stdin ${REGISTRY}
                    docker push ${REGISTRY}/${IMAGE}:${BUILD_NUMBER}
                    docker push ${REGISTRY}/${IMAGE}:latest
                """
            }
        }

        stage('Deploy to Staging') {
            when { branch 'main' }
            steps {
                sh """
                    cd infra/terraform
                    terraform workspace select staging
                    terraform apply -auto-approve \
                        -var="image_tag=${BUILD_NUMBER}"
                """
            }
        }

        stage('Integration Tests') {
            steps {
                sh 'sleep 30'  // Wait for deploy to finish
                sh 'pytest tests/integration/ -v --base-url http://staging-alb-dns'
            }
        }

        stage('Approve Production?') {
            input {
                message "Deploy build #${BUILD_NUMBER} to PRODUCTION?"
                ok "Yes, deploy it!"
            }
        }

        stage('Deploy to Production') {
            when { branch 'main' }
            steps {
                sh """
                    cd infra/terraform
                    terraform workspace select prod
                    terraform apply -auto-approve \
                        -var="image_tag=${BUILD_NUMBER}"
                """
            }
        }

        stage('Health Check') {
            steps {
                sh 'curl -f https://prod-app.yourdomain.com/health'
            }
        }
    }

    post {
        failure {
            slackSend(channel: '#alerts',
                      message: "FAILED: Build #${BUILD_NUMBER} on ${env.JOB_NAME}")
        }
        success {
            archiveArtifacts artifacts: 'reports/**', allowEmptyArchive: true
        }
    }
}
