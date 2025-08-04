pipeline {
    agent none
    parameters {
        booleanParam(name: 'RUN_CHECKS', defaultValue: true, description: 'Run checks on code')
    }
    stages {
        stage('Building and Testing'){
            when{
                equals expected: true, actual: params.RUN_CHECKS
            }
            agent {
                dockerfile {
                    filename 'ci/docker/linux/jenkins/Dockerfile'
                    label 'linux && docker && x86'
//                     additionalBuildArgs '--build-arg PIP_EXTRA_INDEX_URL --build-arg PIP_INDEX_URL --build-arg PIP_CACHE_DIR=/.cache/pip --build-arg UV_CACHE_DIR=/.cache/uv --build-arg CONAN_CENTER_PROXY_V2_URL'
                    args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'
                }
            }
            stages{
                stage('Setup'){
                    stages{
                        stage('Setup Testing Environment'){
                            steps{
                                echo 'Create virtual environment'
                            }
                        }
                        stage('Installing project as editable module'){
                            steps{
                               echo 'Building debug build with coverage data'
                            }
                        }
                    }
                }
                stage('Code Quality') {
                    when{
                        equals expected: true, actual: params.RUN_CHECKS
                    }
                    stages{
                        stage('Running Tests'){
                            parallel {
                                stage('Running Unit Tests'){
                                    steps{
                                        echo 'pytest'
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}