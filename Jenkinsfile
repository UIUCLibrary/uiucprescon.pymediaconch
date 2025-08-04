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
            stages{
                stage('Code Quality') {
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
                                        retry(3){
                                            script{
                                                try{
                                                    sh(
                                                        label: 'Create virtual environment',
                                                        script: '''python3 -m venv bootstrap_uv
                                                                   bootstrap_uv/bin/pip install --disable-pip-version-check uv
                                                                   bootstrap_uv/bin/uv venv venv
                                                                   . ./venv/bin/activate
                                                                   bootstrap_uv/bin/uv pip install --index-strategy unsafe-best-match uv
                                                                   rm -rf bootstrap_uv
                                                                   uv pip install --index-strategy unsafe-best-match -r requirements-dev.txt
                                                                   '''
                                                   )
                                                } catch(e){
                                                    cleanWs(
                                                        patterns: [
                                                                [pattern: 'bootstrap_uv/', type: 'INCLUDE'],
                                                                [pattern: 'venv/', type: 'INCLUDE'],
                                                                [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                            ],
                                                        notFailBuild: true,
                                                        deleteDirs: true
                                                        )
                                                    raise e
                                                }
                                            }
                                        }
                                    }
                                }
                                stage('Installing project as editable module'){
                                    steps{
                                       echo 'Building debug build with coverage data'
                                    }
                                }
                            }
                        }
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