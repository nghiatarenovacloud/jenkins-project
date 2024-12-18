pipeline {
    agent { label "worker-node" }
    environment {
        APP_NAME = "${env.APP_NAME}"
        BRANCH = "${env.BRANCH}"
        BUILD_ENV = "${env.BUILD_ENV}"
        ECR_REPOSITORY = "${env.ECR_REPOSITORY}"
        AWS_REGION = "${env.AWS_REGION}"
        AWS_ACCOUNT_ID = "${env.AWS_ACCOUNT_ID}"
        COMMIT_ID = "${GIT_COMMIT.substring(0, 7)}" // Get the first 7 characters of the commit ID
        IMAGE_TAG = "${new Date().format('HH-dd-MM-yy')}-${COMMIT_ID}" // Format tag for image
        EMAIL_RECIPIENT = "${env.EMAIL_RECIPIENT}"
        APPROVER_EMAIL = "${env.APPROVER_EMAIL}"
        EKS_CLUSTER = "${env.EKS_CLUSTER}"
        LOG_GROUP_NAME = "${env.LOG_GROUP_NAME}"
        LOG_STREAM_NAME = "${env.LOG_STREAM_NAME}"
        VAULT_URL = "http://10.0.11.41:8200" // Vault URL
        ROLE_ID = "9b5aea52-68df-b9bf-08f6-de4b0a44e527" // 
        SECRET_ID = "42d267fb-23e7-6958-3874-53763bcc3c71" // 
    }
    stages {
        stage('Retrieve Secrets from Vault') {
            steps {
                script {
                    // Login to Vault and retrieve the token
                    def loginResponse = sh(script: """
                        curl --silent --request POST --data '{"role_id": "${ROLE_ID}", "secret_id": "${SECRET_ID}"}' ${VAULT_URL}/v1/auth/approle/login
                    """, returnStdout: true)

                    def vaultToken = sh(script: "echo '${loginResponse}' | jq -e -r '.auth.client_token'", returnStdout: true).trim()

                    // Retrieve secrets
                    def secretsResponse = sh(script: """
                        curl --silent --header "X-Vault-Token: ${vaultToken}" --request GET ${VAULT_URL}/v1/secret/data/nghia-flask-app
                    """, returnStdout: true)

                    // Set environment variables using jq
                    env.APP_NAME = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.app_name'", returnStdout: true).trim()
                    env.BRANCH = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.branch'", returnStdout: true).trim()
                    env.BUILD_ENV = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.build_env'", returnStdout: true).trim()
                    env.ECR_REPOSITORY = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.ecr_repository'", returnStdout: true).trim()
                    env.AWS_REGION = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.aws_region'", returnStdout: true).trim()
                    env.AWS_ACCOUNT_ID = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.aws_account_id'", returnStdout: true).trim()
                    env.EMAIL_RECIPIENT = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.email_recipient'", returnStdout: true).trim()
                    env.APPROVER_EMAIL = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.approver_email'", returnStdout: true).trim()
                    env.EKS_CLUSTER = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.eks_cluster'", returnStdout: true).trim()
                    env.LOG_GROUP_NAME = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.log_group_name'", returnStdout: true).trim()
                    env.LOG_STREAM_NAME = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.log_stream_name'", returnStdout: true).trim()
                    env.SONAR_HOST_URL = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.sonar_host_url'", returnStdout: true).trim()
                    env.SONARQUBE_TOKEN = sh(script: "echo '${secretsResponse}' | jq -e -r '.data.data.sonar_token'", returnStdout: true).trim()

                    echo "Secrets retrieved: APP_NAME=${env.APP_NAME}, BRANCH=${env.BRANCH}, BUILD_ENV=${env.BUILD_ENV}, ECR_REPOSITORY=${env.ECR_REPOSITORY}, AWS_REGION=${env.AWS_REGION}, AWS_ACCOUNT_ID=${env.AWS_ACCOUNT_ID}, EMAIL_RECIPIENT=${env.EMAIL_RECIPIENT}, APPROVER_EMAIL=${env.APPROVER_EMAIL}, EKS_CLUSTER=${env.EKS_CLUSTER}, LOG_GROUP_NAME=${env.LOG_GROUP_NAME}, LOG_STREAM_NAME=${env.LOG_STREAM_NAME}, SONAR_HOST_URL=${env.SONAR_HOST_URL}, SONARQUBE_TOKEN=${env.SONARQUBE_TOKEN}"
                }
            }
        }
        stage('Checkout') {
            steps {
                sh "ls" // List files for verification
            }
        }
        stage('Setup Environment and Install Dependencies') {
            steps {
                script {
                    try {
                        sh '''
                            sudo apt update && sudo apt install -y python3 python3-pip python3-venv docker.io unzip
                            python3 -m venv venv  # Create a virtual environment
                            . venv/bin/activate    # Activate the virtual environment
                            pip install --upgrade pip  # Upgrade pip
                            pip install -r requirements.txt  # Install dependencies from requirements.txt
                            pip install pysonar-scanner  # Install pysonar-scanner
                            curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                            unzip -q -o awscliv2.zip && sudo ./aws/install --update > /dev/null 2>&1
                            curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
                            chmod +x ./kubectl && sudo mv ./kubectl /usr/local/bin/kubectl
                            wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                            echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
                            sudo apt-get update && sudo apt-get install -y trivy
                        '''
                    } catch (Exception e) {
                        error "Setup failed: ${e.message}"
                    }
                }
            }
        }
        stage('Setup Docker Permissions') {
            steps {
                script {
                    sh '''
                        sudo usermod -aG docker jenkins || echo "User Jenkins is already in the Docker group."
                        sudo chmod 666 /var/run/docker.sock
                    '''
                }
            }
        }
        stage('Run Tests') {
            steps {
                sh '''
                    . venv/bin/activate
                    ./venv/bin/pytest 
                '''
            }
        }
        stage('Static Code Analysis with SonarQube') {
            steps {
                script {
                    // Create the pyproject.toml file
                    writeFile file: 'pyproject.toml', text: '''
                    [tool.sonar]
                    projectKey = "jenkins-flask-app"
                    sources = "app.py, test_app.py, templates/index.html"
                    exclusions = "**/*.md, **/*.sh, **/*.yaml, **/*.zip, **/__pycache__/**"
                    '''
                    
                    // Run SonarQube analysis with the retrieved credentials
                    try {
                        withCredentials([string(credentialsId: 'jenkins-sonarque', variable: 'SONARQUBE_TOKEN')]) {
                            withEnv(["SONAR_HOST_URL=${SONAR_HOST_URL}"]) {
                                sh '''
                                    . venv/bin/activate  # Activate the virtual environment
                                    ./venv/bin/pysonar-scanner -Dsonar.host.url=$SONAR_HOST_URL -Dsonar.login=$SONARQUBE_TOKEN
                                '''
                            }
                        }
                    } catch (Exception e) {
                        error "SonarQube analysis failed: ${e.message}"
                    }
                }
            }
        }
        stage('Build Docker Image') {
            steps {
                script {
                    try {
                        sh 'docker system prune -af'
                        sh 'docker builder prune --force' // Clean up unused Docker build cache
                        sh "docker build --no-cache -t ${APP_NAME}:${IMAGE_TAG} ." // Build the Docker image
                        sh "docker tag ${APP_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
                    } catch (Exception e) {
                        error "Docker build failed: ${e.message}"
                    }
                }
            }
        }
        stage('Login to ECR') {
            steps {
                script {
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                }
            }
        }
        stage('Push Docker Image') {
            steps {
                sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
            }
        }
        stage('Scan Docker Image with Trivy') {
            steps {
                script {
                    sh 'echo "Scanning Docker image for vulnerabilities..."'
                    def scanResult = sh(script: "trivy image --severity HIGH,CRITICAL --format table ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}", returnStdout: true)

                    // Write scan result to file log
                    writeFile file: 'trivy-scan-results.log', text: scanResult

                    // Print scan result
                    echo "Trivy Scan Results for ${APP_NAME}:${IMAGE_TAG}"
                    echo scanResult
                }
            }
        }
        stage('Manual Approval') {
            steps {
                script {
                    mail to: APPROVER_EMAIL,
                    subject: "Job '${env.JOB_BASE_NAME}' (${env.BUILD_NUMBER}) is waiting for input",
                    body: "Please go to the console output of ${env.BUILD_URL} to approve or reject."
                    input(id: 'userInput', message: 'Do you approve the deployment?', ok: 'Approve')
                }
            }
        }
        stage('Deploy to EKS Cluster') {
            steps {
                script {
                    def deploymentFile = readFile('deployment.yaml')
                    def newImage = "${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
                    deploymentFile = deploymentFile.replaceAll(/(?<=image: ).*/, newImage)
                    writeFile file: 'deployment.yaml', text: deploymentFile
                    // Add kubectl commands to deploy to EKS
                    sh "kubectl apply -f deployment.yaml --context=${EKS_CLUSTER}"
                }
            }
        }
    }
}
