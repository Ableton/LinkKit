@Library([
  'ableton-utils@0.10',
  'groovylint@0.4',
]) _

import groovy.transform.Field


@Field final String LINK_ORIGIN = 'https://github.com/Ableton/link.git'
@Field final String LINK_HASH = 'c1449edb28ccba86396a46a9989b8795960160a9'


void addCheckStages() {
  eager.timedStage('Check') {
    eager.timedNode('generic-linux') {
      checkout scm
      groovylint.check('./Jenkinsfile')
    }
  }
}


void addBuildStages(Map args) {
  eager.timedNode("generic-mac-${args.xcode}") {
    eager.timedStage('Checkout') {
      sh 'env' // Print out all environment variables for debugging purposes
      checkout scm

      sh "git clone ${LINK_ORIGIN}"
      dir('link') {
        sh "git checkout ${LINK_HASH}"
        sh 'git submodule update --init --recursive'
      }
    }

    eager.timedStage('Make Bundle') {
      sh 'make link_dir=link'
      archiveArtifacts 'build/output/LinkKit.zip'
    }
  }
}


runTheBuilds.withBranches(branches: ['master'], acceptPullRequests: true) {
  try {
    runTheBuilds.report('pending', env.CALLBACK_URL)
    addCheckStages()
    addBuildStages(xcode: 'xcode9.3')
  }
  catch (error) {
    runTheBuilds.report('failure', env.CALLBACK_URL)
    throw error
  }

  runTheBuilds.report('success', env.CALLBACK_URL)
}
