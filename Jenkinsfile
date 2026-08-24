pipeline {
    agent any

    stages {
        stage('Secret Scan') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"

                    echo "=== SECRET SCAN ==="
                    echo "Jenkins workspace: $WORKSPACE"
                    echo "Gitleaks path: $GITLEAKS_PATH"

                    docker run --rm \
                        -v jenkins_home:/jenkins_home \
                        zricethezav/gitleaks:latest \
                        dir "$GITLEAKS_PATH" \
                        --report-path "$GITLEAKS_PATH/gitleaks-report.json" \
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
