import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
library identifier: 'JenkinsPythonHelperLibrary@2024.2.0', retriever: modernSCM(
  [$class: 'GitSCMSource',
   remote: 'https://github.com/UIUCLibrary/JenkinsPythonHelperLibrary.git',
   ])

def SUPPORTED_WINDOWS_VERSIONS = ['3.13']

pipeline {
    agent none
    parameters {
        booleanParam(name: 'RUN_CHECKS', defaultValue: true, description: 'Run checks on code')
        booleanParam(name: 'TEST_RUN_TOX', defaultValue: false, description: 'Run Tox Tests')
        booleanParam(name: 'BUILD_PACKAGES', defaultValue: false, description: 'Build Python packages')
        booleanParam(name: 'TEST_PACKAGES', defaultValue: true, description: 'Test Python packages by installing them and running tests on the installed package')
        booleanParam(name: 'INCLUDE_WINDOWS_X86_64', defaultValue: false, description: 'Include x86_64 architecture for Windows')
    }
    stages {
        stage('Building and Testing'){
            when{
                anyOf{
                    equals expected: true, actual: params.RUN_CHECKS
                    equals expected: true, actual: params.TEST_RUN_TOX
                }
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
                                    environment{
                                        CXXFLAGS='--coverage -fprofile-filter-files=src/uiucprescon/pymediaconch/.*'
                                    }
                                    steps{
                                        // Using python setup.py build_ext because there is no other way to capture coverage data directly through python
                                        sh(
                                            label: 'Build python package',
                                            script: '''mkdir -p build/python
                                                       mkdir -p logs
                                                       mkdir -p reports
                                                       . ./venv/bin/activate
                                                       python setup.py build_ext --inplace
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
                                        sh(
                                            label: 'Running pytest',
                                            script: '''mkdir -p reports/pytestcoverage
                                                       . ./venv/bin/activate
                                                       coverage run --parallel-mode --source=src,tests -m pytest --junitxml=./reports/pytest/junit-pytest.xml --basetemp=/tmp/pytest
                                                       '''
                                        )
                                    }
                                }
                            }
                            post{
                                always{
                                    sh(label: 'combining coverage data',
                                       script: '''mkdir -p reports/coverage
                                                  . ./venv/bin/activate
                                                  coverage combine
                                                  coverage xml -o ./reports/coverage/coverage-python.xml
                                                  uvx gcovr --root . --print-summary --keep --json -o reports/coverage/coverage_cpp.json build
                                                  uvx gcovr --add-tracefile reports/coverage/coverage_cpp.json --keep --print-summary --xml -o reports/coverage/coverage_cpp.xml
                                                  '''
                                          )
                                    recordCoverage(tools: [[parser: 'COBERTURA', pattern: 'reports/coverage/*.xml']])
                                }
                                cleanup{
                                    sh "git clean -dfx"
                                }
                            }
                        }
                    }
                }
                stage('Tox'){
                    when {
                       equals expected: true, actual: params.TEST_RUN_TOX
                    }
                    parallel{
                        stage('Linux'){
                            environment{
                                PIP_CACHE_DIR='/tmp/pipcache'
                                UV_INDEX_STRATEGY='unsafe-best-match'
                                UV_TOOL_DIR='/tmp/uvtools'
                                UV_PYTHON_INSTALL_DIR='/tmp/uvpython'
                                UV_CACHE_DIR='/tmp/uvcache'
                            }
                            when{
                                expression {return nodesByLabel('linux && docker').size() > 0}
                            }
                            steps{
                                script{
                                    def envs = []
                                    node('docker && linux'){
                                        try{
                                            checkout scm
                                            docker.image('python').inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'){
                                                sh(script: 'python -m venv venv && venv/bin/pip install --disable-pip-version-check uv')
                                                envs = sh(
                                                    label: 'Get tox environments',
                                                    script: './venv/bin/uvx --quiet --with tox-uv tox list -d --no-desc',
                                                    returnStdout: true,
                                                ).trim().split('\n')
                                            }
                                        } finally{
                                            sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                        }
                                    }
                                    parallel(
                                        envs.collectEntries{toxEnv ->
                                            def version = toxEnv.replaceAll(/py(\d)(\d+)/, '$1.$2')
                                            [
                                                "Tox Environment: ${toxEnv}",
                                                {
                                                    node('docker && linux'){
                                                        checkout scm
                                                        def image
                                                        lock("${env.JOB_NAME} - ${env.NODE_NAME}"){
                                                            image = docker.build(UUID.randomUUID().toString(), '-f ci/docker/linux/tox/Dockerfile --build-arg PIP_INDEX_URL .')
                                                        }
                                                        try{
                                                            try{
                                                                image.inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'){
                                                                    retry(3){
                                                                        try{
                                                                            sh( label: 'Running Tox',
                                                                                script: """python3 -m venv venv && venv/bin/pip install --disable-pip-version-check uv
                                                                                           venv/bin/uvx --python ${version} --python-preference system --with tox-uv tox run -e ${toxEnv} -vv
                                                                                        """
                                                                                )
                                                                        } finally{
                                                                            cleanWs(
                                                                                patterns: [
                                                                                    [pattern: 'venv/', type: 'INCLUDE'],
                                                                                    [pattern: '.tox', type: 'INCLUDE'],
                                                                                    [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                                                ]
                                                                            )
                                                                        }
                                                                    }
                                                                }
                                                            } finally {
                                                                sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                            }
                                                        } finally {
                                                            sh "docker rmi ${image.id}"
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    )
                                }
                            }
                        }
                        stage('Windows'){
                             when{
                                 expression {return nodesByLabel('windows && docker && x86').size() > 0}
                             }
                             environment{
                                 UV_INDEX_STRATEGY='unsafe-best-match'
                                 PIP_CACHE_DIR='C:\\Users\\ContainerUser\\Documents\\cache\\pipcache'
                                 UV_TOOL_DIR='C:\\Users\\ContainerUser\\Documents\\uvtools'
                                 UV_PYTHON_INSTALL_DIR='C:\\Users\\ContainerUser\\Documents\\cache\\uvpython'
                                 UV_CACHE_DIR='C:\\cache\\uvcache'
                             }
                             steps{
                                 script{
                                     def envs = []
                                     node('docker && windows'){
                                         checkout scm
                                         try{
                                            docker.image(env.DEFAULT_PYTHON_DOCKER_IMAGE ? env.DEFAULT_PYTHON_DOCKER_IMAGE: 'python')
                                                .inside("\
                                                    --mount type=volume,source=uv_python_install_dir,target=${env.UV_PYTHON_INSTALL_DIR} \
                                                    --mount type=volume,source=pipcache,target=${env.PIP_CACHE_DIR} \
                                                    "
                                                    // --mount type=volume,source=uv_cache_dir,target=${env.UV_CACHE_DIR}\
                                                ){
                                                 bat(script: 'python -m venv venv && venv\\Scripts\\pip install --disable-pip-version-check uv')
                                                 envs = bat(
                                                     label: 'Get tox environments',
                                                     script: '@.\\venv\\Scripts\\uvx --quiet --constraint=requirements-dev.txt --with-requirements requirements-dev.txt --with tox-uv tox list -d --no-desc',
                                                     returnStdout: true,
                                                 ).trim().split('\r\n')
                                            }
                                         } finally{
                                             bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                         }
                                     }
                                     parallel(
                                         envs.collectEntries{toxEnv ->
                                             def version = toxEnv.replaceAll(/py(\d)(\d+)/, '$1.$2')
                                             [
                                                 "Tox Environment: ${toxEnv}",
                                                 {
                                                     node('docker && windows'){
                                                        def maxRetries = 1
                                                        def image
                                                        checkout scm
                                                        lock("${env.JOB_NAME} - ${env.NODE_NAME}"){
                                                            retry(maxRetries){
                                                                image = docker.build(UUID.randomUUID().toString(), '-f scripts/resources/windows/Dockerfile --build-arg UV_INDEX_URL --build-arg CONAN_CENTER_PROXY_V2_URL --build-arg CHOCOLATEY_SOURCE' + (env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE ? " --build-arg FROM_IMAGE=${env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE} ": ' ') + '.')
                                                            }
                                                        }
                                                        try{
                                                            try{
                                                                checkout scm
                                                                image.inside("\
                                                                    --mount type=volume,source=uv_python_install_dir,target=${env.UV_PYTHON_INSTALL_DIR} \
                                                                    --mount type=volume,source=pipcache,target=${env.PIP_CACHE_DIR} \
                                                                    "
                                                                    // --mount type=volume,source=uv_cache_dir,target=${env.UV_CACHE_DIR}\
                                                                ){
                                                                    retry(maxRetries){
                                                                        try{
                                                                            bat(label: 'Running Tox',
                                                                                script: """uv python install cpython-${version}
                                                                                           uvx -p ${version} --constraint=requirements-dev.txt --with tox-uv tox run -e ${toxEnv} --workdir %WORKSPACE_TMP%\\.tox
                                                                                        """
                                                                            )
                                                                        } finally{
                                                                            cleanWs(
                                                                                patterns: [
                                                                                        [pattern: '.tox', type: 'INCLUDE'],
                                                                                    ],
                                                                                notFailBuild: true,
                                                                                deleteDirs: true
                                                                            )
                                                                        }
                                                                    }
                                                                }
                                                            } finally {
                                                                bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                            }
                                                        } finally{
                                                            bat "docker rmi --force --no-prune ${image.id}"
                                                        }
                                                     }
                                                 }
                                             ]
                                         }
                                     )
                                 }
                             }
                        }
                    }
                }
            }
        }
        stage('Python Packaging'){
            when{
                equals expected: true, actual: params.BUILD_PACKAGES
            }
            failFast true
            parallel{
                stage('Platform Wheels: Windows'){
                    when {
                        equals expected: true, actual: params.INCLUDE_WINDOWS_X86_64
                    }
                    steps{
                        echo 'windows_wheels(SUPPORTED_WINDOWS_VERSIONS, params.TEST_PACKAGES, params, wheelStashes, SHARED_PIP_CACHE_VOLUME_NAME)'
                    }
                }
            }
        }
    }
}