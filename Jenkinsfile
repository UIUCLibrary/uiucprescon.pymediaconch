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
                            args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'
                        }
                    }
                    environment{
                        PIP_CACHE_DIR='/tmp/pipcache'
                        UV_TOOL_DIR='/tmp/uvtools'
                        UV_PYTHON_INSTALL_DIR='/tmp/uvpython'
                        UV_CACHE_DIR='/tmp/uvcache'
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
                                    options{
                                        timeout(10)
                                    }
                                    steps{
                                        sh(
                                            label: 'Build python package',
                                            script: '''mkdir -p build/python
                                                       mkdir -p logs
                                                       mkdir -p reports
                                                       . ./venv/bin/activate
                                                       uv pip install --index-strategy unsafe-best-match --verbose -e .
                                                       '''
                                        )
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