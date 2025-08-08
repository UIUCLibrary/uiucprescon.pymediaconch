import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
library identifier: 'JenkinsPythonHelperLibrary@2024.2.0', retriever: modernSCM(
  [$class: 'GitSCMSource',
   remote: 'https://github.com/UIUCLibrary/JenkinsPythonHelperLibrary.git',
   ])
def SHARED_PIP_CACHE_VOLUME_NAME = 'pipcache'
def SUPPORTED_WINDOWS_VERSIONS = ['3.13']
def SUPPORTED_MAC_VERSIONS = ['3.13']

def wheelStashes = []

def installMSVCRuntime(cacheLocation){
    def cachedFile = "${cacheLocation}\\vc_redist.x64.exe".replaceAll(/\\\\+/, '\\\\')
    withEnv(
        [
            "CACHED_FILE=${cachedFile}",
            "RUNTIME_DOWNLOAD_URL=https://aka.ms/vs/17/release/vc_redist.x64.exe"
        ]
    ){
        lock("${cachedFile}-${env.NODE_NAME}"){
            powershell(
                label: 'Ensuring vc_redist runtime installer is available',
                script: '''if ([System.IO.File]::Exists("$Env:CACHED_FILE"))
                           {
                                Write-Host 'Found installer'
                           } else {
                                Write-Host 'No installer found'
                                Write-Host 'Downloading runtime'
                                [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12;Invoke-WebRequest "$Env:RUNTIME_DOWNLOAD_URL" -OutFile "$Env:CACHED_FILE"
                           }
                        '''
            )
        }
        powershell(label: 'Install VC Runtime', script: 'Start-Process -filepath "$Env:CACHED_FILE" -ArgumentList "/install", "/passive", "/norestart" -Passthru | Wait-Process;')
    }
}

def mac_wheels(pythonVersions, testPackages, params, wheelStashes){
    def selectedArches = []
    def allValidArches = ['arm64', 'x86_64']
    if(params.INCLUDE_MACOS_X86_64 == true){
        selectedArches << 'x86_64'
    }
    if(params.INCLUDE_MACOS_ARM == true){
        selectedArches << 'arm64'
    }

    parallel([failFast: true] << pythonVersions.collectEntries{ pythonVersion ->
        [
            "Python ${pythonVersion} - Mac":{
                stage("Python ${pythonVersion} - Mac"){
                    stage("Single arch wheels for Python ${pythonVersion}"){
                        parallel([failFast: true] << allValidArches.collectEntries{arch ->
                            def newWheelStage = "MacOS - Python ${pythonVersion} - ${arch}: wheel"
                            return [
                                "${newWheelStage}": {
                                    stage(newWheelStage){
                                        if(selectedArches.contains(arch)){
                                            stage("Build Wheel (${pythonVersion} MacOS ${arch})"){
                                                agent("mac && python${pythonVersion} && ${arch}"){
                                                    try{
                                                        timeout(60){
                                                            sh(label: 'Building wheel', script: "scripts/build_mac_wheel.sh --uv=./venv/bin/uv --python-version=${pythonVersion}")
                                                        }
                                                        stash includes: 'dist/*.whl', name: "python${pythonVersion} mac ${arch} wheel"
                                                        wheelStashes << "python${pythonVersion} mac ${arch} wheel"
                                                        archiveArtifacts artifacts: 'dist/*.whl'
                                                    } finally {
                                                        sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                    }
                                                }
                                            }
                                            if(testPackages == true){
                                                stage("Test Wheel (${pythonVersion} MacOS ${arch})"){
                                                    agent("mac && python${pythonVersion} && ${arch}"){
                                                        checkout scm
                                                        try{
                                                            unstash "python${pythonVersion} mac ${arch} wheel"
                                                            findFiles(glob: 'dist/*.whl').each{
                                                                timeout(60){
                                                                    sh(label: 'Running Tox',
                                                                       script: """python${pythonVersion} -m venv venv
                                                                       ./venv/bin/python -m pip install --disable-pip-version-check --upgrade pip
                                                                       ./venv/bin/pip install --disable-pip-version-check -r requirements-dev.txt
                                                                       ./venv/bin/tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')}"""
                                                                    )
                                                                }
                                                            }
                                                        } finally {
                                                            sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                        }

                                                    }
                                                }
                                            }
                                        } else {
                                            Utils.markStageSkippedForConditional(newWheelStage)
                                        }
                                    }
                                }
                            ]
                        }
                        )
                    }
                    if(params.INCLUDE_MACOS_X86_64 && params.INCLUDE_MACOS_ARM){
                        stage("Universal2 Wheel: Python ${pythonVersion}"){
                            stage('Make Universal2 wheel'){
                                retry(3){
                                    node("mac && python${pythonVersion}") {
                                        try{
                                            checkout scm
                                            unstash "python${pythonVersion} mac arm64 wheel"
                                            unstash "python${pythonVersion} mac x86_64 wheel"
                                            def wheelNames = []
                                            findFiles(excludes: '', glob: 'dist/*.whl').each{wheelFile ->
                                                wheelNames.add(wheelFile.path)
                                            }
                                            sh(label: 'Make Universal2 wheel',
                                               script: """python${pythonVersion} -m venv venv
                                                          . ./venv/bin/activate
                                                          pip install --disable-pip-version-check --upgrade pip
                                                          pip install --disable-pip-version-check wheel delocate
                                                          mkdir -p out
                                                          delocate-merge  ${wheelNames.join(' ')} --verbose -w ./out/
                                                          rm dist/*.whl
                                                           """
                                               )
                                           def fusedWheel = findFiles(excludes: '', glob: 'out/*.whl')[0]
                                           def props = readTOML( file: 'pyproject.toml')['project']
                                           def universalWheel = "py3exiv2bind-${props.version}-cp${pythonVersion.replace('.','')}-cp${pythonVersion.replace('.','')}-macosx_11_0_universal2.whl"
                                           sh "mv ${fusedWheel.path} ./dist/${universalWheel}"
                                           stash includes: 'dist/*.whl', name: "python${pythonVersion} mac-universal2 wheel"
                                           wheelStashes << "python${pythonVersion} mac-universal2 wheel"
                                           archiveArtifacts artifacts: 'dist/*.whl'
                                        } finally{
                                            sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                        }
                                    }
                                }
                            }
                            if(testPackages == true){
                                stage("Test universal2 Wheel"){
                                    def archStages = [:]
                                    ['x86_64', 'arm64'].each{arch ->
                                        archStages["Test Python ${pythonVersion} universal2 Wheel on ${arch} mac"] = {
                                            testPythonPkg(
                                                agent: [
                                                    label: "mac && python${pythonVersion} && ${arch}",
                                                ],
                                                testSetup: {
                                                    checkout scm
                                                    unstash "python${pythonVersion} mac-universal2 wheel"
                                                },
                                                retries: 3,
                                                testCommand: {
                                                    findFiles(glob: 'dist/*.whl').each{
                                                        withEnv(['UV_INDEX_STRATEGY=unsafe-best-match']){
                                                            sh(label: 'Running Tox',
                                                               script: """python${pythonVersion} -m venv venv
                                                                          trap "rm -rf venv" EXIT
                                                                          ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                                          trap "rm -rf venv && rm -rf .tox" EXIT
                                                                          ./venv/bin/uvx --python=${pythonVersion} --constraint=requirements-dev.txt --with tox-uv tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')}
                                                                       """
                                                            )
                                                        }
                                                    }
                                                },
                                                post:[
                                                    cleanup: {
                                                        sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                    },
                                                    success: {
                                                         archiveArtifacts artifacts: 'dist/*.whl'
                                                    }
                                                ]
                                            )
                                        }
                                    }
                                    parallel(archStages)
                                }
                            }
                        }
                    }
                }
            }
        ]}
    )
}
def windows_wheels(pythonVersions, testPackages, params, wheelStashes, sharedPipCacheVolumeName){
    parallel([failFast: true] << pythonVersions.collectEntries{ pythonVersion ->
        def newStage = "Python ${pythonVersion} - Windows"
        [
            "${newStage}": {
                stage(newStage){
                    if(params.INCLUDE_WINDOWS_X86_64 == true){
                        stage("Build Wheel (${pythonVersion} Windows)"){
                            node('windows && docker && x86_64'){
                                def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                try{
                                    checkout scm
                                    try{
                                        powershell(label: 'Building Wheel for Windows', script: "scripts/build_windows.ps1 -PythonVersion ${pythonVersion} -DockerImageName ${dockerImageName}")
                                        stash includes: 'dist/*.whl', name: "python${pythonVersion} windows wheel"
                                        wheelStashes << "python${pythonVersion} windows wheel"
                                        archiveArtifacts artifacts: 'dist/*.whl'
                                    } finally {
                                        bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                    }
                                } finally {
                                    powershell(
                                        label: "Untagging Docker Image used",
                                        script: "docker image rm --no-prune ${dockerImageName}",
                                        returnStatus: true
                                    )
                                }
                            }
                        }
                        def wheelTestingStageName = "Test Wheel (${pythonVersion} Windows)"
                        stage(wheelTestingStageName){
                            if(testPackages == true){
                                node('windows && docker'){
                                    withEnv([
                                        'PIP_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\pipcache',
                                        'UV_TOOL_DIR=C:\\Users\\ContainerUser\\Documents\\uvtools',
                                        'UV_PYTHON_INSTALL_DIR=C:\\Users\\ContainerUser\\Documents\\uvpython',
                                        'UV_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\uvcache',
                                        'UV_INDEX_STRATEGY=unsafe-best-match',
                                    ]){
                                        retry(2){
                                            checkout scm
                                            try{
                                                docker.image(env.DEFAULT_PYTHON_DOCKER_IMAGE ? env.DEFAULT_PYTHON_DOCKER_IMAGE: 'python').inside("--mount source=uv_python_install_dir,target=C:\\Users\\ContainerUser\\Documents\\uvpython --mount source=msvc-runtime,target=c:\\msvc_runtime --mount source=${sharedPipCacheVolumeName},target=${env:PIP_CACHE_DIR}"){
                                                    installMSVCRuntime('c:\\msvc_runtime\\')
                                                    unstash "python${pythonVersion} windows wheel"
                                                    findFiles(glob: 'dist/*.whl').each{
                                                        bat """python -m pip install --disable-pip-version-check uv
                                                               uvx -p ${pythonVersion} --constraint requirements-dev.txt --with tox-uv tox run -e py${pythonVersion.replace('.', '')}  --installpkg ${it.path}
                                                            """
                                                    }
                                                }
                                            } finally {
                                                bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                            }
                                        }
                                    }
                                }
                            } else {
                                Utils.markStageSkippedForConditional(wheelTestingStageName)
                            }
                        }
                    } else {
                        Utils.markStageSkippedForConditional(newStage)
                    }
                }
            }
        ]
    })
}

pipeline {
    agent none
    parameters {
        booleanParam(name: 'RUN_CHECKS', defaultValue: true, description: 'Run checks on code')
        booleanParam(name: 'TEST_RUN_TOX', defaultValue: false, description: 'Run Tox Tests')
        booleanParam(name: 'BUILD_PACKAGES', defaultValue: false, description: 'Build Python packages')
        booleanParam(name: 'TEST_PACKAGES', defaultValue: true, description: 'Test Python packages by installing them and running tests on the installed package')
        booleanParam(name: 'INCLUDE_MACOS_ARM', defaultValue: false, description: 'Include ARM(m1) architecture for Mac')
        booleanParam(name: 'INCLUDE_MACOS_X86_64', defaultValue: false, description: 'Include x86_64 architecture for Mac')
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
                stage('Platform Wheels: Mac'){
                    when {
                        anyOf {
                            equals expected: true, actual: params.INCLUDE_MACOS_X86_64
                            equals expected: true, actual: params.INCLUDE_MACOS_ARM
                        }
                    }
                    steps{
                        mac_wheels(SUPPORTED_MAC_VERSIONS, params.TEST_PACKAGES, params, wheelStashes)
                    }
                }
                stage('Platform Wheels: Windows'){
                    when {
                        equals expected: true, actual: params.INCLUDE_WINDOWS_X86_64
                    }
                    steps{
                        windows_wheels(SUPPORTED_WINDOWS_VERSIONS, params.TEST_PACKAGES, params, wheelStashes, SHARED_PIP_CACHE_VOLUME_NAME)
                    }
                }
            }
        }
    }
}