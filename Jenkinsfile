#!/usr/bin/env groovy

pipeline {
    agent {
        label 'docker'
    }

    environment {
        MASTER_BOUNCER_KEY = credentials('master-bouncer-key')
    }

    options {
        ansiColor("xterm")
        buildDiscarder(logRotator(numToKeepStr: '50'))
        timeout(time: 20, unit: 'MINUTES')
    }

    stages {
        stage('Build') {
            steps {
                sh 'docker-compose down --rmi=all --volumes --remove-orphans'
                sh 'docker-compose build --pull'
            }
        }

        stage('Test') {
            parallel {
                stage('Ruby 2.4') {
                    steps {
                        sh 'docker-compose run --name coverage test /bin/bash -lc "rvm-exec 2.4 bin/run_tests.sh"'
                    }
                }
                stage('Ruby 2.5') {
                    steps {
                        sh 'docker-compose run --rm test /bin/bash -lc "rvm-exec 2.5 bin/run_tests.sh"'
                    }
                }
                stage('Ruby 2.6') {
                    steps {
                        sh 'docker-compose run --rm test /bin/bash -lc "rvm-exec 2.6 bin/run_tests.sh"'
                    }
                }
            }

            post {
                always {
                    sh 'docker cp coverage:/usr/src/app/coverage .'
                    sh 'docker-compose down --rmi=all --volumes --remove-orphans'

                    publishHTML target: [
                      allowMissing: false,
                      alwaysLinkToLastBuild: false,
                      keepAll: true,
                      reportDir: "coverage",
                      reportFiles: 'index.html',
                      reportName: 'Coverage Report'
                    ]
                }
            }
        }
    }
}
