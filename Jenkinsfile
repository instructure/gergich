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
    stage('Setup') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: '44aa91d6-ab24-498a-b2b4-911bcb17cc35', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER_NAME')]) {
          sh """
            #!/bin/bash
            set -exuE

            # filter secrets that end in "_KEY" or "_SECRET" but still mention their presence
            printenv | sort | sed -E 's/(.*_(KEY|SECRET))=.*/\1 is present/g'
          """
          sh 'docker network prune -f'
          sh 'docker compose down --rmi=all --volumes --remove-orphans'
        }
      }
    }
    
    stage('Build') {
      steps {
        withCredentials([sshUserPrivateKey(credentialsId: '44aa91d6-ab24-498a-b2b4-911bcb17cc35', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER_NAME')]) {
          echo "Building with SSH username '$SSH_USER_NAME'"
          sh 'docker compose build --pull --build-arg SSH_KEY_PATH --build-arg SSH_USER_NAME --build-arg USER_ID=$(id -u)'
        }
      }
    }

    stage('Test') {
      parallel {
        stage('Ruby 2.6') {
          steps {
            withCredentials([sshUserPrivateKey(credentialsId: '44aa91d6-ab24-498a-b2b4-911bcb17cc35', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER_NAME')]) {
              script {
                sh ''' #!/usr/bin/env bash
                  set -exuE

                  cleanup() {
                    kill "$SSH_AGENT_PID"
                  }
                  trap cleanup EXIT

                  if [[ -v SSH_AUTH_SOCK ]]; then
                    echo "ssh is set and running!"
                  else
                    if [[ -z "$SSH_KEY_PATH" ]]; then
                      echo "No SSH agent present and no key file path supplied, aborting!"
                      exit 1
                    fi
                    echo "No SSH agent present, starting one"
                    SSH_AGENT_STARTED=1
                    eval `ssh-agent`
                    ssh-add "$SSH_KEY_PATH"
                  fi

                  docker compose run --name coverage \
                    -v "$SSH_KEY_PATH:$SSH_KEY_PATH" \
                    -e RUBY_LOG_LEVEL=DEBUG \
                    -e SSH_KEY_PATH \
                    -e SSH_USER_NAME \
                    test /bin/bash -lc "rvm-exec 2.6 bin/run_tests.sh" 

                  docker cp coverage:/usr/src/app/coverage .
                '''

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

        stage('Ruby 2.7') {
          steps {
            withCredentials([sshUserPrivateKey(credentialsId: '44aa91d6-ab24-498a-b2b4-911bcb17cc35', keyFileVariable: 'SSH_KEY_PATH', usernameVariable: 'SSH_USER_NAME')]) {
              script {
                sh ''' #!/usr/bin/env bash
                set -exuE

                cleanup() {
                  kill "$SSH_AGENT_PID"
                }
                trap cleanup EXIT

                if [[ -v SSH_AUTH_SOCK ]]; then
                  echo "ssh is set and running!"
                else
                  if [[ -z "$SSH_KEY_PATH" ]]; then
                    echo "No SSH agent present and no key file path supplied, aborting!"
                    exit 1
                  fi
                  echo "No SSH agent present, starting one"
                  SSH_AGENT_STARTED=1
                  eval `ssh-agent`
                  ssh-add "$SSH_KEY_PATH"
                fi

                docker compose run --rm \
                  -v "$SSH_KEY_PATH:$SSH_KEY_PATH" \
                  -e RUBY_LOG_LEVEL=DEBUG \
                  -e SSH_KEY_PATH \
                  -e SSH_USER_NAME \
                  test /bin/bash -lc "rvm-exec 2.7 bin/run_tests.sh"
                '''
              }
            }
          }
        }
      }
    }
  } // stages

  post {
    always {
      script{
        sh 'docker-compose down --rmi=all --volumes --remove-orphans'
      }
    }
  }
} // pipeline