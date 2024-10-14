
pipeline {
    agent { label "worker-node" }
    environment {
        APP_NAME = "jenkins-flask-app"
        BRANCH = "main"
        BUILD_ENV = "dev"
        ECR_REPOSITORY = "nghia-cicd-jenkins"
        AWS_REGION = "ap-southeast-1"
        AWS_ACCOUNT_ID = "879654127886"
        COMMIT_ID = "${env.GIT_COMMIT.substring(0, 7)}" // Get the first 7 characters of the commit ID
        IMAGE_TAG = "${new Date().format('HH-dd-MM-yy')}-${COMMIT_ID}" // Format tag for image
        EMAIL_RECIPIENT = "nghia.ta@renovacloud.com"
        APPROVER_EMAIL = "nghia.ta@renovacloud.com"
        EKS_CLUSTER = "nghia-test-eks"
        LOG_GROUP_NAME = 'nghia-jenkins-ci'
        LOG_STREAM_NAME = 'nghia-jenkins-ci-application'
    }
    stages {
        stage('Install Dependencies') {
            steps {
                script {
                    sh '''
                        sudo apt update
                        sudo apt install -y python3 python3-pip python3-venv docker.io unzip
                        curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
                        unzip -o awscliv2.zip
                        sudo ./aws/install --update
                        aws --version
                        docker --version
                        curl -LO "https://storage.googleapis.com/kubernetes-release/release/$(curl -s https://storage.googleapis.com/kubernetes-release/release/stable.txt)/bin/linux/amd64/kubectl"
                        chmod +x ./kubectl
                        sudo mv ./kubectl /usr/local/bin/kubectl
                        kubectl version --client
                        sudo apt-get install -y wget apt-transport-https gnupg lsb-release
                        wget -qO - https://aquasecurity.github.io/trivy-repo/deb/public.key | sudo apt-key add -
                        echo "deb https://aquasecurity.github.io/trivy-repo/deb $(lsb_release -sc) main" | sudo tee /etc/apt/sources.list.d/trivy.list
                        sudo apt-get update
                        sudo apt-get install -y trivy
                        trivy --version
                    '''
                }
            }
        }  
        stage('Disk Space Cleanup') {
            steps {
                script {
                    // Enable Global Build Discarders
                    sh '''
                        echo "Cleaning up old builds and images..."
                        docker image prune -af
                        docker system prune -af
                        
                    '''
                }
            }
        } 
        stage('Setup Docker Permissions') {
            steps {
                script {
                    sh '''
                        echo "Adding Jenkins user to Docker group..."
                        sudo usermod -aG docker jenkins || echo "User Jenkins is already in the Docker group."
                        echo "Restarting Jenkins service..."
                        sudo systemctl restart jenkins
                    '''
                    sh '''
                        echo "Checking permissions for Docker socket..."
                        ls -l /var/run/docker.sock
                    '''
                    sh '''
                        echo "Changing permissions for Docker socket..."
                        sudo chmod 666 /var/run/docker.sock
                    '''
                    sh '''
                        echo "Authenticating Docker..."
                        sudo -u jenkins docker ps
                    '''
                }
            }
        } 

        stage('Prebuild') {
            steps {
                sh 'python3 -m venv venv' // Create a virtual environment
            }
        }
        
        stage('Checkout') {
            steps {
                git url: 'https://github.com/nghiatarenovacloud/jenkins-project.git', branch: 'main'
                sh "ls" // List files for verification
            }
        }
        
        stage('Setup') {
            steps {
                sh "./venv/bin/pip install -r requirements.txt" // Install dependencies
            }
        }

        stage('Test') {
            steps {
                sh '''
                    . venv/bin/activate
                    ./venv/bin/pytest 
                '''
            }
        }

        stage('Login to ECR') {
            steps {
                script {
                    sh 'echo "Logging in to Amazon ECR..."'
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"
                }
            }
        }

        stage('Build Docker Image') {
            steps {
                sh 'echo "Building Docker image..."'
                sh 'docker system prune -af'
                sh 'docker builder prune --force' // Clean up unused Docker build cache
                sh "docker build --no-cache -t ${APP_NAME}:${IMAGE_TAG} ." // Build the Docker image
                sh 'echo "Listing Docker images..."'
                sh 'docker images'
                sh "echo \"Tagging Docker image with IMAGE_TAG\""
                sh "docker tag ${APP_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
            }
        }

        stage('Scan Docker Image with Trivy') {
            steps {
                script {
                    sh 'echo "Scanning Docker image for vulnerabilities..."'
                    def scanResult = sh(script: "trivy image --severity HIGH,CRITICAL --format json ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}", returnStdout: true)


                    writeFile file: 'trivy-scan-results.log', text: scanResult
                    // def jsonContent = readFile('trivy-scan-results.json')
                    // def jsonValid = isValidJson(jsonContent)
                    // if (jsonValid) {
                    
                    // sh '''
                    //     aws logs put-log-events --log-group-name $LOG_GROUP_NAME --log-stream-name $LOG_STREAM_NAME --log-events file://trivy-scan-results.json
                    // '''
                    // } else {
                    //     error("Invalid JSON format in trivy-scan-results.json")
                    // }
                    // // Check if the JSON is valid
                    // if (isValidJson(scanResult)) {
                    //     // Check if log group exists
                    //     def logGroupExists = sh(script: "aws logs describe-log-groups --log-group-name-prefix $LOG_GROUP_NAME", returnStdout: true).contains(LOG_GROUP_NAME)
                        
                    //     // Create log group if it doesn't exist
                    //     if (!logGroupExists) {
                    //         sh "aws logs create-log-group --log-group-name $LOG_GROUP_NAME"
                    //     }

                    //     // Check if log stream exists
                    //     def logStreamExists = sh(script: "aws logs describe-log-streams --log-group-name $LOG_GROUP_NAME --log-stream-name-prefix $LOG_STREAM_NAME", returnStdout: true).contains(LOG_STREAM_NAME)
                        
                    //     // Create log stream if it doesn't exist
                    //     if (!logStreamExists) {
                    //         sh "aws logs create-log-stream --log-group-name $LOG_GROUP_NAME --log-stream-name $LOG_STREAM_NAME"
                    //     }

                    //     // Put log events
                    //     sh '''
                    //         aws logs put-log-events --log-group-name $LOG_GROUP_NAME --log-stream-name $LOG_STREAM_NAME --log-events file://trivy-scan-results.json
                    //     '''
                    // } else {
                    //     error("Invalid JSON format in trivy-scan-results.json")
                    // }

                    // Uncomment the following lines to send email notifications based on vulnerabilities found
                    /*
                    def highVulns = scanResult.split('\n').findAll { it.contains('HIGH') }
                    def criticalVulns = scanResult.split('\n').findAll { it.contains('CRITICAL') }

                    if (highVulns) {
                        mail to: EMAIL_RECIPIENT,
                            subject: "Trivy Scan Results - HIGH Vulnerabilities in ${APP_NAME}:${IMAGE_TAG}",
                            body: "The following HIGH vulnerabilities were found in the image:\n\n${highVulns.join('\n')}\n\nPlease address these issues."
                    }

                    if (criticalVulns) {
                        mail to: EMAIL_RECIPIENT,
                            subject: "Trivy Scan Results - CRITICAL Vulnerabilities in ${APP_NAME}:${IMAGE_TAG}",
                            body: "The following CRITICAL vulnerabilities were found in the image:\n\n${criticalVulns.join('\n')}\n\nImmediate action is required!"
                    }
                    */
                }
            }
        }

        stage('Push Docker Image') {
            steps {
                sh 'echo "Pushing Docker image to ECR..."'
                sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
                echo "Docker image pushed successfully."
            }
        }

        stage('Manual Approval') {
            steps {
                script {
                    mail to: APPROVER_EMAIL,
                         subject: "Job '${env.JOB_BASE_NAME}' (${env.BUILD_NUMBER}) is waiting for input",
                         body: "Please go to the console output of ${env.BUILD_URL} to approve or reject."
                    def userInput = input(id: 'userInput', message: 'Do you approve the deployment?', ok: 'Approve')
                }
            }
        }

        stage('Deploy to EKS Cluster') {
            steps {
                script {
                    sh "aws eks --region ${AWS_REGION} update-kubeconfig --name ${EKS_CLUSTER}"
                    sh "kubectl config current-context"
                    sh "kubectl apply -f deployment.yaml" // Deploy the application to EKS
                    echo "Deployed to EKS Cluster."
                }
            }
        }
    }
}
// Function to validate JSON
            boolean isValidJson(String json) {
                try {
                    new groovy.json.JsonSlurper().parseText(json)
                    return true
                } catch (Exception e) {
                    return false
                }
            }