pipeline {
    agent any
    options { timeout(time: 10, unit: 'MINUTES') }
    triggers { pollSCM('H/2 * * * *') }
    stages {
        stage('Checkout') {
            steps { git branch: 'main', url: 'https://github.com/sx2310/ai-qa.git' }
        }
        stage('Deploy') {
            steps { sh 'sudo bash /opt/ai-qa/deploy.sh' }
        }
        stage('Verify') {
            steps { sh 'curl -fsS http://127.0.0.1/health' }
        }
    }
    post {
        failure { echo '部署失败：查看 Console Output，并在服务器执行 journalctl -u ai-qa -n 50' }
        success { echo '部署成功：全链路健康检查通过' }
    }
}
