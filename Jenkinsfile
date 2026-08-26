pipeline {
    agent any

    stages {
        stage('Secret Scan - Filesystem') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"

                    echo "=== FILESYSTEM SECRET SCAN ==="
                    echo "Workspace: $WORKSPACE"
                    echo "Scan path: $GITLEAKS_PATH"

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

        stage('Secret Scan - Git History') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    GITLEAKS_PATH="/jenkins_home${SCAN_PATH}"

                    echo "=== GIT HISTORY SECRET SCAN ==="
                    echo "Git repository: $GITLEAKS_PATH/.git"

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

    post {
        always {
            archiveArtifacts(
                artifacts: 'gitleaks-*.json',
                allowEmptyArchive: true
            )
        }

        failure {
            echo 'Secret scan menemukan potensi credential yang ter-expose. Cek hasil Gitleaks.'
        }

        success {
            echo 'Filesystem dan Git history secret scan clean.'
        }
    }
}
