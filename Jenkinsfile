pipeline {
    agent { 
        docker {
            image 'python:3.12' // Use a specific Python image
            args '-v $WORKSPACE:/app' // Mount the workspace
        }
    }
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
        IMAGE_TAG = "${IMAGE_NAME}:${env.BUILD_NUMBER}"
    }
    stages {
        // stage('Prebuild') {
        //     steps {
        //         script {
        //             // Install Python and pip
        //             sh '''
        //                 sudo apt update
        //                 sudo apt install python3 python3-pip -y
        //             '''

        //             // Check Python installation
        //             def pythonVersion = sh(script: 'python3 --version', returnStdout: true).trim()
        //             echo "Python Version: ${pythonVersion}"

        //             // Check pip installation
        //             def pipVersion = sh(script: 'pip3 --version', returnStdout: true).trim()
        //             echo "pip Version: ${pipVersion}"
        //         }
        //     }
        // }
        stage('Install Requirements') {
            steps {
                script {
                    // Change to the app directory
                    sh 'cd /app'
                    // Install requirements
                    sh 'pip install -r requirements.txt'
                }
            }
        }
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