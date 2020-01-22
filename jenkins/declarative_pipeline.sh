pipeline {
    agent any
    environment{
        DOCKER_TAG = getDockerTag()
    }
    stages{
        stage('Build Docker Image'){
            steps{
                sh "docker build . -t dmedema/node-app:${DOCKER_TAG}"
            }
        }
        stage('DockerHub Push'){
            # Add credentials into Jenkins 'docker-hub'
            # withCredentials binds a variable to the password
            # dockerHubPwd
            steps {
                withCredentials([string(credentialsId: 'docker-hub', variable: 'dockerHubPwd')]) {
                    sh "docker login -u dmedema -p ${dockerHubPwd}"
                    sh "docker push dmedema/node-app:${DOCKER_TAG}"
                }
            }
        }
        stage('Deploy to k8s'){
            steps{
                sh "chmod +x changeTag.sh"
                sh "./changeTag.sh ${DOCKER_TAG}"
                sshagent(['kops-machine']){
                    sh "scp -o StrictHostKeyChecking=no services.yml node-app-prod.yml ec2-user@PublicIP:/home/ec2-user"
                    script{
                        try{
                            sh "ssh ec2-user@PublicIP kubectl apply -f ."
                        }catch(error){
                            sh "ssh ec2-user@PublicIP kubectl create -f ."
                        }
                    }
                }
            }
        }
    }
}

def getDockerTag(){
    def tag = sh script: 'git rev-parse HEAD', return Stdout: true
    return tag
}
















