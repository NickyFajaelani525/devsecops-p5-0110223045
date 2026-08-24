pipeline {
    agent any

    stages {
        stage('Secret Scan') {
            steps {
                sh '''
                    echo "=== CHECK WORKSPACE MOUNT ==="

                    docker run --rm \
                        -v "$WORKSPACE:/repo" \
                        alpine:latest \
                        sh -c '
                            echo "--- FILES ---"
                            ls -lah /repo

                            echo "--- FILE SIZES ---"
                            wc -c /repo/Jenkinsfile /repo/README.md
                        '

                    echo "=== GITLEAKS SCAN ==="

                    docker run --rm \
                        -v "$WORKSPACE:/repo" \
                        zricethezav/gitleaks:latest \
                        dir /repo \
                        --report-path /repo/gitleaks-report.json \
                        --report-format json \
                        --redact \
                        --exit-code 1
                '''
            }
        }
    }

    post {
        always {
            archiveArtifacts(
                artifacts: 'gitleaks-report.json',
                allowEmptyArchive: true
            )
        }

        failure {
            echo 'Secret scan menemukan potensi credential yang ter-expose. Cek gitleaks-report.json.'
        }

        success {
            echo 'Secret scan clean. Aman lanjut ke stage berikutnya.'
        }
    }
}
