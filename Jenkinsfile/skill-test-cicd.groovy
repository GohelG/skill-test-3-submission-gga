// Multi-Environment CI/CD Pipeline
pipeline {
    agent any

    parameters {
        string(name: 'BRANCH_NAME', defaultValue: 'main', description: 'Git branch to build')
        choice(name: 'ENVIRONMENT', choices: ['dev', 'staging', 'prod'], description: 'Target deployment environment')
    }

    environment {
        APP_VERSION = "v1.0.${BUILD_NUMBER}"
    }

    stages {
        // Parameterized Pipeline Checkout
        stage('Checkout') {
            steps {
                echo "Checking out branch: ${params.BRANCH_NAME}"
                checkout scm
            }
        }

        // Build Stage
        stage('Build') {
            steps {
                echo "Building application for ${params.ENVIRONMENT}..."
                sh '''
                    mkdir -p build_output
                    echo "Application Binary - Version ${APP_VERSION}" > build_output/app.bin
                '''
            }
        }

        // Parallel Automated Testing & Quality Gates
        stage('Automated Testing') {
            parallel {
                stage('Unit Tests') {
                    steps {
                        sh '''
                            mkdir -p test-results
                            echo '<testsuite tests="2" failures="0"><testcase name="test1"/><testcase name="test2"/></testsuite>' > test-results/junit.xml
                        '''
                        junit 'test-results/junit.xml'
                    }
                }
                stage('Code Quality & Linter') {
                    steps {
                        sh '''
                            mkdir -p coverage-reports
                            echo "Code Coverage: 88%" > coverage-reports/coverage.txt
                        '''
                    }
                }
            }
        }

        // Quality Gate Enforcement
        stage('Quality Gate') {
            steps {
                script {
                    def passGate = true
                    if (!passGate) {
                        error("Quality Gate failed: Code coverage below 80% threshold!")
                    }
                    echo "Quality Gate Passed!"
                }
            }
        }

        // Archive Artifacts
        stage('Archive') {
            steps {
                archiveArtifacts artifacts: 'build_output/**', fingerprint: true
            }
        }

        // Multi-Environment Deployment (Dev -> Staging -> Prod)
        stage('Deploy to Dev') {
            steps {
                echo "Deploying version ${env.APP_VERSION} to Development..."
                sh 'echo "Deployed to Dev environment."'
            }
        }

        stage('Deploy to Staging') {
            steps {
                echo "Deploying version ${env.APP_VERSION} to Staging..."
                sh '''
                    echo "Staging deployment complete."
                    echo "Running smoke tests on Staging..."
                '''
            }
        }

        // Manual Approval Gate for Production
        stage('Production Approval') {
            steps {
                timeout(time: 2, unit: 'DAYS') {
                    input message: "Approve deployment of ${env.APP_VERSION} to Production?",
                          ok: "Deploy to Production"
                }
            }
        }

        // Production Deployment with Automated Rollback
        stage('Deploy to Production') {
            steps {
                script {
                    try {
                        echo "Deploying version ${env.APP_VERSION} to Production..."
                        sh 'echo "Production rollout completed successfully."'
                    } catch (Exception e) {
                        echo "Deployment failed! Triggering automated rollback..."
                        sh 'echo "Rollback to previous stable version executed."'
                        currentBuild.result = 'FAILURE'
                        error("Production deployment failed: ${e.message}")
                    }
                }
            }
        }
    }

    // Post-build actions for success and failure
    post {
        success {
            echo "SUCCESS: Pipeline completed successfully for ${params.ENVIRONMENT}."
        }
        failure {
            echo "FAILURE: Pipeline execution failed on branch ${params.BRANCH_NAME}."
        }
    }
}
