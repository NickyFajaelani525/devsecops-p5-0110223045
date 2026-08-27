pipeline {
    agent any

    environment {
        ACR_NAME = 'acrminisoc2026nick-e6cdh0h4dthegjg0.azurecr.io'
        IMAGE_NAME = 'minisoc-backend'
    }

    stages {
        stage('Secret Scan - Filesystem') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    sh '''
                        SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                        GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"
                        docker run --rm \
                            -v jenkins_home:/jenkins_home \
                            zricethezav/gitleaks:latest \
                            dir "$GITLEAKS_PATH" \
                            --report-path "$GITLEAKS_PATH/gitleaks-filesystem.json" \
                            --report-format json \
                            --redact \
                            --exit-code 1
                    '''
                }
            }
        }

        stage('Secret Scan - Git History') {
            steps {
                catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
                    sh '''
                        SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                        GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"
                        docker run --rm \
                            -v jenkins_home:/jenkins_home \
                            zricethezav/gitleaks:latest \
                            git "$GITLEAKS_PATH" \
                            --report-path "$GITLEAKS_PATH/gitleaks-history.json" \
                            --report-format json \
                            --redact \
                            --exit-code 1
                    '''
                }
            }
        }

        stage('Build Image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(script: "git rev-parse --short HEAD", returnStdout: true).trim()
                }
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    BUILD_CONTEXT="/jenkins_home${SCAN_PATH}/backend"
                    docker build -t ${IMAGE_NAME}:${IMAGE_TAG} "$BUILD_CONTEXT"
                '''
            }
        }

        stage('Push to ACR') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'AZ_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'AZ_CLIENT_SECRET')
                ]) {
                    sh '''
                        echo "$AZ_CLIENT_SECRET" | docker login "$ACR_NAME" -u "$AZ_CLIENT_ID" --password-stdin
                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} ${ACR_NAME}/${IMAGE_NAME}:${IMAGE_TAG}
                        docker push ${ACR_NAME}/${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'gitleaks-*.json', allowEmptyArchive: true
        }
        failure {
            echo 'Ada stage yang gagal — cek Console Output untuk detail (secret scan atau push ke ACR).'
        }
        success {
            echo 'Pipeline sukses: secret scan clean, image ter-build dan ter-push ke ACR.'
        }
    }
}
