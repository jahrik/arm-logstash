#!/usr/bin/env groovy

env.ELASTICSEARCH_URL = 'http://es_venus:9200'

node('arm32v7') {

    try {

        stage('build') {
            // Clean workspace
            deleteDir()
            // Checkout the app at the given commit sha from the webhook
            checkout scm
            sh "make"
        }

        stage('test') {
            // Run any testing suites
        }

        stage('push') {
            // Push to Dockerhub
            sh "make push"
        }

    } catch(error) {
        throw error

    } finally {
        // Any cleanup operations needed, whether we hit an error or not

    }
}

node('master') {

    try {

        stage('scm') {
            // Clean workspace
            deleteDir()
            // Checkout the app at the given commit sha from the webhook
            checkout scm
        }

        stage('provision') {
            // Ansible
            echo "Running ${env.BUILD_ID} on ${env.JENKINS_URL}"
            echo "ELASTICSEARCH_URL: ${env.ELASTICSEARCH_URL}"
            ansiColor('xterm') {
                ansiblePlaybook(
                    playbook: 'playbook.yml',
                    inventory: 'inventory.ini',
                    colorized: true)
            }
        }

        stage('deploy') {
            // Docker deploy
            sh "make deploy"
        }

    } catch(error) {
        throw error

    } finally {
        // Any cleanup operations needed, whether we hit an error or not

    }
}
