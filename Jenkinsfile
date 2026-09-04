pipeline {
    agent any

    options {
        skipDefaultCheckout(true)
        disableConcurrentBuilds()
    }

    environment {
        ACR_NAME = 'acrminisoc2026nick-e6cdh0h4dthegjg0.azurecr.io'
        IMAGE_NAME = 'minisoc-backend'

        // Persistent Terraform state inside Jenkins volume
        TF_STATE = '/jenkins_home/terraform-state/terraform.tfstate'
        TF_PLAN = '/jenkins_home/workspace/minisoc-pipeline/tfplan'
    }

    stages {

        stage('Clean Workspace') {
            steps {
                cleanWs()
            }
        }

        stage('Checkout SCM') {
            steps {
                checkout scm
            }
        }

        stage('Secret Scan - Filesystem') {
            steps {
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

        stage('Secret Scan - Git History') {
            steps {
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

        stage('SCA - Trivy Filesystem') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    TRIVY_PATH="/jenkins_home${SCAN_PATH}"
                    TRIVY_CACHE="/jenkins_home/trivy-cache"

                    docker run --rm \
                        -v jenkins_home:/jenkins_home \
                        aquasec/trivy:latest \
                        fs "$TRIVY_PATH/backend" \
                        --cache-dir "$TRIVY_CACHE" \
                        --format json \
                        --output "$TRIVY_PATH/trivy-fs-report.json" \
                        --severity MEDIUM,HIGH,CRITICAL \
                        --exit-code 1
                '''
            }
        }

        stage('Build Image') {
            steps {
                script {
                    env.IMAGE_TAG = sh(
                        script: "git rev-parse --short HEAD",
                        returnStdout: true
                    ).trim()
                }

                sh '''
                    docker build \
                        -t ${IMAGE_NAME}:${IMAGE_TAG} \
                        "${WORKSPACE}/backend"
                '''
            }
        }

        stage('Container Scan - Trivy Image') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    TRIVY_PATH="/jenkins_home${SCAN_PATH}"
                    TRIVY_CACHE="/jenkins_home/trivy-cache"

                    docker run --rm \
                        -v /var/run/docker.sock:/var/run/docker.sock \
                        -v jenkins_home:/jenkins_home \
                        aquasec/trivy:latest \
                        image "${IMAGE_NAME}:${IMAGE_TAG}" \
                        --cache-dir "$TRIVY_CACHE" \
                        --format json \
                        --output "$TRIVY_PATH/trivy-image-report.json" \
                        --severity MEDIUM,HIGH,CRITICAL \
                        --ignore-unfixed \
                        --exit-code 1
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
                        echo "$AZ_CLIENT_SECRET" | docker login "$ACR_NAME" \
                            -u "$AZ_CLIENT_ID" \
                            --password-stdin

                        docker tag ${IMAGE_NAME}:${IMAGE_TAG} \
                            ${ACR_NAME}/${IMAGE_NAME}:${IMAGE_TAG}

                        docker push \
                            ${ACR_NAME}/${IMAGE_NAME}:${IMAGE_TAG}
                    '''
                }
            }
        }

        stage('IaC Scan - Trivy Config') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    TRIVY_PATH="/jenkins_home${SCAN_PATH}"
                    TRIVY_CACHE="/jenkins_home/trivy-cache"

                    docker run --rm \
                        -v jenkins_home:/jenkins_home \
                        aquasec/trivy:latest \
                        config "$TRIVY_PATH/terraform" \
                        --cache-dir "$TRIVY_CACHE" \
                        --format json \
                        --output "$TRIVY_PATH/trivy-config-report.json" \
                        --severity MEDIUM,HIGH,CRITICAL \
                        --ignorefile "$TRIVY_PATH/terraform/.trivyignore" \
                        --exit-code 1
                '''
            }
        }

        stage('Terraform Init') {
            steps {
                sh '''
                    SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                    TF_PATH="/jenkins_home${SCAN_PATH}/terraform"

                    docker run --rm \
                        -v jenkins_home:/jenkins_home \
                        -w "$TF_PATH" \
                        hashicorp/terraform:1.16.0 \
                        init
                '''
            }
        }

        stage('Terraform Plan') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
                    string(credentialsId: 'azure-ssh-public-key', variable: 'TF_VAR_ssh_public_key')
                ]) {
                    sh '''
                        SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                        TF_PATH="/jenkins_home${SCAN_PATH}/terraform"
                        STATE_PATH="/jenkins_home/terraform-state/terraform.tfstate"
                        PLAN_PATH="/jenkins_home${SCAN_PATH}/tfplan"

                        docker run --rm \
                            -v jenkins_home:/jenkins_home \
                            -w "$TF_PATH" \
                            -e ARM_CLIENT_ID \
                            -e ARM_CLIENT_SECRET \
                            -e ARM_TENANT_ID \
                            -e ARM_SUBSCRIPTION_ID \
                            -e TF_VAR_ssh_public_key \
                            hashicorp/terraform:1.16.0 \
                            plan \
                            -state="$STATE_PATH" \
                            -out="$PLAN_PATH"

                        echo "===== TERRAFORM PLAN ====="

                        docker run --rm \
                            -v jenkins_home:/jenkins_home \
                            -w "$TF_PATH" \
                            hashicorp/terraform:1.16.0 \
                            show \
                            -no-color \
                            "$PLAN_PATH"
                    '''
                }
            }
        }

        stage('Approval Gate') {
            steps {
                input(
                    message: 'Terraform plan sudah direview. Lanjutkan Terraform Apply?',
                    ok: 'Approve & Apply',
                    cancel: 'Abort'
                )
            }
        }

        stage('Terraform Apply') {
            steps {
                withCredentials([
                    string(credentialsId: 'azure-client-id', variable: 'ARM_CLIENT_ID'),
                    string(credentialsId: 'azure-client-secret', variable: 'ARM_CLIENT_SECRET'),
                    string(credentialsId: 'azure-tenant-id', variable: 'ARM_TENANT_ID'),
                    string(credentialsId: 'azure-subscription-id', variable: 'ARM_SUBSCRIPTION_ID'),
                    string(credentialsId: 'azure-ssh-public-key', variable: 'TF_VAR_ssh_public_key')
                ]) {
                    sh '''
                        SCAN_PATH="${WORKSPACE#/var/jenkins_home}"
                        TF_PATH="/jenkins_home${SCAN_PATH}/terraform"
                        STATE_PATH="/jenkins_home/terraform-state/terraform.tfstate"
                        PLAN_PATH="/jenkins_home${SCAN_PATH}/tfplan"

                        docker run --rm \
                            -v jenkins_home:/jenkins_home \
                            -w "$TF_PATH" \
                            -e ARM_CLIENT_ID \
                            -e ARM_CLIENT_SECRET \
                            -e ARM_TENANT_ID \
                            -e ARM_SUBSCRIPTION_ID \
                            -e TF_VAR_ssh_public_key \
                            hashicorp/terraform:1.16.0 \
                            apply \
                            -state="$STATE_PATH" \
                            "$PLAN_PATH"
                    '''
                }
            }
        }
    }

    post {
        always {
            archiveArtifacts artifacts: 'gitleaks-*.json, trivy-*-report.json',
                allowEmptyArchive: true
        }

        failure {
            echo 'Pipeline gagal — cek Console Output untuk detail security scan atau Terraform.'
        }

        success {
            echo 'Pipeline sukses: security scan clean, image ter-push, Terraform approved dan applied.'
        }
    }
}
