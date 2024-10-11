pipeline {
    agent { label "worker-node"}
    environment {
        // IMAGE_NAME = 'sanjeevkt720/jenkins-flask-app'
        // IMAGE_TAG = "${IMAGE_NAME}:${env.BUILD_NUMBER}"
        // KUBECONFIG = credentials('kubeconfig-credentials-id')
        APP_NAME = "jenkins-flask-app"
        BRANCH = "main"
        BUILD_ENV = "dev"
        ECR_REPOSITORY = "nghia-cicd-jenkins"
        AWS_REGION = "ap-southeast-1"
        AWS_ACCOUNT_ID = "879654127886"
        
        CODEARTIFACT_REPOSITORY = "oxii-codeartifact"
        CONTAINER_NAME = "srt-iotp-kex-container"
        PACKAGE_NAME = ''
        COMMIT_ID = ''
        DATE = ''
        CODEARTIFACT_TAG = ''
        LATEST_VERSION = ''
        IMAGE_TAG = "${IMAGE_NAME}:${env.BUILD_NUMBER}"
    }
    stages {

        stage('Checkout') {
            steps {
                git url: 'https://github.com/nghiatarenovacloud/jenkins-project.git', branch: 'main'
                sh "ls"
            }
        }
        stage('Setup') {
            steps {
                sh "pip install -r requirements.txt"
            }
        }
        stage('Test') {
            steps {
                sh "pytest"
                sh "whoami"
            }
        }
        stage('Login to ECR') {
            steps {
               script{
                sh 'echo "Logging in to Amazon ECR..."'
                    sh "aws ecr get-login-password --region ${AWS_REGION} | docker login --username AWS --password-stdin ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

                    sh 'echo "Building Docker image..."'
                    sh 'docker builder prune --force'
                    sh "docker build --no-cache -t ${APP_NAME}:${IMAGE_TAG} ."
                    sh 'echo "Listing Docker images..."'
                    sh 'docker images'
                    sh "echo \"Tagging Docker image with IMAGE_TAG\""
                    sh "docker tag ${APP_NAME}:${IMAGE_TAG} ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"

                    sh 'echo "Pushing Docker image to ECR..."'
                    sh "docker push ${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com/${ECR_REPOSITORY}:${IMAGE_TAG}"
               }
            }
        }
        stage('Build Docker Image')
        {
            steps
            {
                sh 'docker build -t ${IMAGE_TAG} .'
                echo "Docker image build successfully"
                sh "docker images"
            }
        }
        stage('Push Docker Image')
        {
            steps
            {
                sh 'docker push ${IMAGE_TAG}'
                echo "Docker image push successfully"
            }
        }
        stage('Deploy to EKS Cluster') {
            steps {
                sh "kubectl apply -f deployment.yaml"
                echo "Deployed to EKS Cluster"
            }
        }
    }
}