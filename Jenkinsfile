import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
library identifier: 'JenkinsPythonHelperLibrary@2024.2.0', retriever: modernSCM(
  [$class: 'GitSCMSource',
   remote: 'https://github.com/UIUCLibrary/JenkinsPythonHelperLibrary.git',
   ])

def PYPI_CONFIG_ID = 'pypi_config'

def SHARED_PIP_CACHE_VOLUME_NAME = 'pipcache'

def SUPPORTED_WINDOWS_VERSIONS = [
    '3.11',
    '3.12',
    '3.13'
]
def SUPPORTED_MAC_VERSIONS = [
    '3.11',
    '3.12',
    '3.13'
]
def SUPPORTED_LINUX_VERSIONS = [
    '3.11',
    '3.12',
    '3.13'
]

def retryTimes = 3

def wheelStashes = []

def getPypiConfig(pypiConfigId) {
    node(){
        try{
            configFileProvider([configFile(fileId: pypiConfigId, variable: 'CONFIG_FILE')]) {
                def config = readJSON( file: CONFIG_FILE)
                return config['deployment']['indexes']
            }
        } catch(e){
            return []
        }
    }
}

def linux_wheels(pythonVersions, testPackages, params, wheelStashes, retryTimes){
    def selectedArches = []
    def allValidArches = [
        // Arm64 on linux won't build libcurl
        //'arm64',
        'x86_64'
    ]
//     if(params.INCLUDE_LINUX_ARM == true){
//         selectedArches << 'arm64'
//     }
    if(params.INCLUDE_LINUX_X86_64 == true){
        selectedArches << 'x86_64'
    }
    parallel([failFast: true] << pythonVersions.collectEntries{ pythonVersion ->
        def newVersionStage = "Python ${pythonVersion} - Linux"
        return [
            "${newVersionStage}": {
                stage(newVersionStage){
                    parallel([failFast: true] << allValidArches.collectEntries{ arch ->
                        def newStage = "Python ${pythonVersion} Linux ${arch} Wheel"
                        return [
                            "${newStage}": {
                                stage(newStage){
                                    if(selectedArches.contains(arch)){
                                        withEnv([
                                            'PIP_CACHE_DIR=/tmp/pipcache',
                                            'UV_TOOL_DIR=/tmp/uvtools',
                                            'UV_PYTHON_INSTALL_DIR=/tmp/uvpython',
                                            'UV_CACHE_DIR=/tmp/uvcache',
                                        ]){
                                            stage("Build Wheel (${pythonVersion} Linux ${arch})"){
                                                node("linux && docker && ${arch}"){
                                                    retry(retryTimes){
                                                        checkout scm
                                                        try{
                                                            def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                                            try{
                                                                sh( script: "scripts/build_linux_wheels.sh --python-version ${pythonVersion} --docker-image-name  ${dockerImageName}")
                                                                stash includes: 'dist/*manylinux*.*whl', name: "python${pythonVersion} linux - ${arch} - wheel"
                                                                wheelStashes << "python${pythonVersion} linux - ${arch} - wheel"
                                                                archiveArtifacts artifacts: 'dist/*manylinux*.*whl'
                                                            } finally {
                                                                sh "docker image rm --no-prune ${dockerImageName}"
                                                            }
                                                        } finally{
                                                            sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                        }
                                                    }
                                                }
                                            }
                                            def testWheelStageName = "Test Wheel (${pythonVersion} Linux ${arch})"
                                            stage(testWheelStageName){
                                                if(testPackages == true){
                                                    retry(retryTimes){
                                                        node("docker && linux && ${arch}"){
                                                            checkout scm
                                                            unstash "python${pythonVersion} linux - ${arch} - wheel"
                                                            try{
                                                                docker.image('python').inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp')
                                                                {
                                                                    sh(
                                                                        label: 'Testing with tox',
                                                                        script: """python3 -m venv venv
                                                                                   ./venv/bin/pip install --disable-pip-version-check uv
                                                                                   trap "rm -rf venv" EXIT
                                                                                   ./venv/bin/uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                                   ./venv/bin/uvx --constraint requirements-dev.txt --with tox-uv tox -e py${pythonVersion.replace('.', '')} --installpkg ${findFiles(glob:'dist/*.whl')[0].path} -vv
                                                                                """
                                                                    )
                                                                }
                                                            } finally {
                                                                sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                            }
                                                        }
                                                    }
                                                } else {
                                                    Utils.markStageSkippedForConditional(testWheelStageName)
                                                }
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
            }
        ]
    })
}

def mac_wheels(pythonVersions, testPackages, params, wheelStashes, retryTimes){
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
                                                node("mac && python${pythonVersion} && ${arch}"){
                                                    checkout scm
                                                    try{
                                                        timeout(60){
                                                            sh(label: 'Building wheel', script: "scripts/build_mac_wheel.sh ${pythonVersion}")
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
                                                    node("mac && python${pythonVersion} && ${arch}"){
                                                        checkout scm
                                                        try{
                                                            unstash "python${pythonVersion} mac ${arch} wheel"
                                                            findFiles(glob: 'dist/*.whl').each{
                                                                timeout(60){
                                                                    sh(label: 'Running Tox',
                                                                       script: """python${pythonVersion} -m venv venv
                                                                       ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                                       ./venv/bin/uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                       ./venv/bin/uvx --constraint=requirements-dev.txt --with tox_uv tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv"""
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
                                retry(retryTimes){
                                    node("mac && python${pythonVersion}") {
                                        checkout scm
                                        try{
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
                                           sh "mv ${fusedWheel.path} ./dist/"
                                           stash includes: 'dist/*.whl', name: "python${pythonVersion} mac-universal2 wheel"
                                           wheelStashes << "python${pythonVersion} mac-universal2 wheel"
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
                                            node("mac && python${pythonVersion}") {
                                                checkout scm
                                                retry(retryTimes){
                                                    try{
                                                        unstash "python${pythonVersion} mac-universal2 wheel"
                                                        findFiles(glob: 'dist/*.whl').each{
                                                            sh(label: 'Running Tox',
                                                               script: """python${pythonVersion} -m venv venv
                                                                          trap "rm -rf venv" EXIT
                                                                          ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                                          trap "rm -rf venv && rm -rf .tox" EXIT
                                                                          ./venv/bin/uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                          ./venv/bin/uvx --python=${pythonVersion} --constraint=requirements-dev.txt --with tox-uv tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv
                                                                       """
                                                            )
                                                        }
                                                    } finally {
                                                        sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    parallel(archStages)
                                }
                            }
                            node(){
                                unstash "python${pythonVersion} mac-universal2 wheel"
                                archiveArtifacts artifacts: 'dist/*.whl'
                                cleanWs(
                                    patterns: [
                                            [pattern: 'dist/', type: 'INCLUDE'],
                                        ],
                                    notFailBuild: true,
                                    deleteDirs: true
                                )
                            }
                        }
                    }
                }
            }
        ]}
    )
}
def windows_wheels(pythonVersions, testPackages, params, wheelStashes, retryTimes, sharedPipCacheVolumeName){
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
                                        retry(retryTimes){
                                            try{
                                                powershell(label: 'Building Wheel for Windows', script: "scripts/build_windows.ps1 -PythonVersion ${pythonVersion} -DockerImageName ${dockerImageName}")
                                            } catch(e){
                                                cleanWs(
                                                    patterns: [
                                                        [pattern: 'dist/', type: 'INCLUDE'],
                                                        [pattern: 'build/', type: 'INCLUDE'],
                                                        [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                    ],
                                                    notFailBuild: true,
                                                    deleteDirs: true
                                                )
                                                throw e
                                            }
                                        }
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
                                    ]){
                                        retry(retryTimes){
                                            checkout scm
                                            try{
                                                docker.image(env.DEFAULT_PYTHON_DOCKER_IMAGE ? env.DEFAULT_PYTHON_DOCKER_IMAGE: 'python').inside("--mount source=uv_python_install_dir,target=C:\\Users\\ContainerUser\\Documents\\uvpython --mount source=msvc-runtime,target=c:\\msvc_runtime --mount source=${sharedPipCacheVolumeName},target=${env:PIP_CACHE_DIR}"){
//                                                     installMSVCRuntime('c:\\msvc_runtime\\')
                                                    unstash "python${pythonVersion} windows wheel"
                                                    findFiles(glob: 'dist/*.whl').each{
                                                        bat """python -m pip install --disable-pip-version-check uv
                                                               uv export --frozen --only-dev --no-hashes > requirements-dev.txt ; `
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
        // Unable to build on arm64 linux because conan is unable to build libcurl which is required by libmediainfo
        // booleanParam(name: 'INCLUDE_LINUX_ARM', defaultValue: false, description: 'Include ARM architecture for Linux')
        booleanParam(name: 'INCLUDE_LINUX_X86_64', defaultValue: true, description: 'Include x86_64 architecture for Linux')
        booleanParam(name: 'INCLUDE_MACOS_ARM', defaultValue: false, description: 'Include ARM(m1) architecture for Mac')
        booleanParam(name: 'INCLUDE_MACOS_X86_64', defaultValue: false, description: 'Include x86_64 architecture for Mac')
        booleanParam(name: 'INCLUDE_WINDOWS_X86_64', defaultValue: false, description: 'Include x86_64 architecture for Windows')
        booleanParam(name: 'DEPLOY_PYPI', defaultValue: false, description: 'Deploy to pypi')
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
                        beforeAgent true
                    }
                    agent {
                        dockerfile {
                            filename 'ci/docker/linux/jenkins/Dockerfile'
                            label 'linux && docker && x86'
                            args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'
                            additionalBuildArgs '--build-arg CONAN_CENTER_PROXY_V2_URL'
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
                                        retry(retryTimes){
                                            script{
                                                try{
                                                    sh(
                                                        label: 'Create virtual environment',
                                                        script: '''python3 -m venv --clear bootstrap_uv
                                                                   trap "rm -rf bootstrap_uv" EXIT
                                                                   bootstrap_uv/bin/pip install --disable-pip-version-check uv
                                                                   bootstrap_uv/bin/uv venv  --python-preference=only-system  venv
                                                                   . ./venv/bin/activate
                                                                   bootstrap_uv/bin/uv sync --frozen --only-group dev --active
                                                                   bootstrap_uv/bin/uv pip install uv --python venv
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
                                                    throw e
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
                                                       python setup.py build_ext --inplace --build-temp build/temp  --build-lib build/lib --debug
                                                       '''
                                        )
                                    }
                                }
                            }
                        }
                        stage('Sphinx Documentation'){
                            steps {
                                sh(
                                    label: 'Building docs',
                                    script: '''. ./venv/bin/activate
                                               sphinx-build -b html docs/source build/docs/html -d build/docs/doctrees -v -w logs/build_sphinx.log -W --keep-going
                                            '''
                                )
                                publishHTML(
                                    [
                                        allowMissing: false,
                                        alwaysLinkToLastBuild: false,
                                        keepAll: false, reportDir: 'build/docs/html',
                                        reportFiles: 'index.html',
                                        reportName: 'Documentation',
                                        reportTitles: ''
                                    ]
                                )
                            }
                            post{
                                always {
                                    recordIssues(tools: [sphinxBuild(id: 'sphinxBuild', name: 'Sphinx Documentation Build', pattern: 'logs/build_sphinx.log')])
                                    archiveArtifacts artifacts: 'logs/build_sphinx.log'
                                    script{
                                        def props = readTOML( file: 'pyproject.toml')['project']
                                        zip archive: true, dir: 'build/docs/html', glob: '', zipFile: "dist/${props.name}-${props.version}.doc.zip"
                                    }
                                    stash includes: 'dist/*.doc.zip,build/docs/html/**', name: 'DOCS_ARCHIVE'
                                }
                           }
                       }
                        stage('Running Tests'){
                            parallel {
                                stage('Clang Tidy'){
                                    steps{
                                        sh 'mkdir -p logs'
                                        catchError(buildResult: 'SUCCESS', message: 'clang-tidy found some issues', stageResult: 'UNSTABLE') {
                                            sh 'clang-tidy src/uiucprescon/pymediaconch/pymediaconch.cpp -- $(./venv/bin/python -m pybind11 --includes) -Ibuild/temp/include | tee logs/clang-tidy.log'
                                        }
                                    }
                                    post{
                                        always{
                                            recordIssues(tools: [clangTidy(pattern: 'logs/clang-tidy.log')], qualityGates: [[threshold: 1, type: 'TOTAL', unstable: true]])
                                        }
                                    }
                                }
                                stage('Running Unit Tests'){
                                    environment{
                                        PYTEST_JUNIT_XML='reports/pytest/junit-pytest.xml'
                                    }
                                    steps{
                                        sh(
                                            label: 'Running pytest',
                                            script: '''mkdir -p reports/pytestcoverage
                                                       . ./venv/bin/activate
                                                       coverage run --parallel-mode --source=src,tests -m pytest --junitxml=$PYTEST_JUNIT_XML --basetemp=/tmp/pytest -o pythonpath=src
                                                       '''
                                        )
                                    }
                                    post{
                                        always{
                                            junit env.PYTEST_JUNIT_XML
                                        }
                                    }
                                }
                                stage('Documentation linkcheck'){
                                    steps {
                                        catchError(buildResult: 'SUCCESS', message: 'Sphinx docs linkcheck', stageResult: 'UNSTABLE') {
                                            sh(
                                                label: 'Running Sphinx docs linkcheck',
                                                script: '''. ./venv/bin/activate
                                                           python -m sphinx -b doctest docs/source build/docs -d build/docs/doctrees --no-color --builder=linkcheck --fail-on-warning -w logs/linkcheck.log
                                                           '''
                                                )
                                        }
                                    }
                                    post{
                                        always {
                                            recordIssues(tools: [sphinxBuild(id: 'doclinkcheck', name: 'linkcheck', pattern: 'logs/linkcheck.log')])
                                        }
                                    }
                                }
                                stage('Documentation Doctest'){
                                    steps {
                                        sh(
                                            label: 'Running Doctest Tests',
                                            script: '''. ./venv/bin/activate
                                                       coverage run --parallel-mode --source=src -m sphinx -b doctest docs/source dist/docs/html -d build/docs/doctrees --no-color -w logs/doctest.txt
                                                    '''
                                            )
                                    }
                                    post{
                                        always {
                                            recordIssues(tools: [sphinxBuild(id: 'doctest', name: 'Doctest', pattern: 'logs/doctest.txt')])
                                        }
                                    }
                                }
                                stage('MyPy Static Analysis') {
                                    environment{
                                        MYPYPATH='build/lib'
                                    }
                                    steps{
                                        catchError(buildResult: 'SUCCESS', message: 'MyPy found issues', stageResult: 'UNSTABLE') {
                                            sh(
                                                label: 'Running Mypy',
                                                script: '''. ./venv/bin/activate
                                                           uv pip install mypy lxml
                                                           mkdir -p logs
                                                           mypy -p uiucprescon.pymediaconch --html-report reports/mypy/html > logs/mypy.log
                                                           '''
                                           )
                                        }
                                    }
                                    post {
                                        always {
                                            recordIssues(tools: [myPy(name: 'MyPy', pattern: 'logs/mypy.log')])
                                            publishHTML([allowMissing: false, alwaysLinkToLastBuild: false, keepAll: false, reportDir: 'reports/mypy/html/', reportFiles: 'index.html', reportName: 'MyPy HTML Report', reportTitles: ''])
                                        }
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
                                                    node('docker && linux && x86_64'){
                                                        checkout scm
                                                        def image
                                                        lock("${env.JOB_NAME} - ${env.NODE_NAME}"){
                                                            retry(retryTimes){
                                                                image = docker.build(UUID.randomUUID().toString(), '-f ci/docker/linux/tox/Dockerfile --build-arg PIP_INDEX_URL --build-arg CONAN_CENTER_PROXY_V2_URL .')
                                                            }
                                                        }
                                                        try{
                                                            try{
                                                                image.inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'){
                                                                    retry(retryTimes){
                                                                        try{
                                                                            sh( label: 'Running Tox',
                                                                                script: """python3 -m venv venv && venv/bin/pip install --disable-pip-version-check uv
                                                                                           venv/bin/uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                                           venv/bin/uvx --python ${version} --python-preference system --with tox-uv tox run -e ${toxEnv} -vv
                                                                                        """
                                                                                )
                                                                        } catch(e){
                                                                            cleanWs(
                                                                                patterns: [
                                                                                    [pattern: 'venv/', type: 'INCLUDE'],
                                                                                    [pattern: '.tox', type: 'INCLUDE'],
                                                                                    [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                                                ]
                                                                            )
                                                                            throw e
                                                                        }
                                                                    }
                                                                }
                                                            } finally {
                                                                sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                            }
                                                        } finally {
                                                            if (image){
                                                                sh "docker rmi --force --no-prune ${image.id}"
                                                            }
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
                                                .inside("--mount type=volume,source=uv_python_install_dir,target=${env.UV_PYTHON_INSTALL_DIR} " +
                                                        "--mount type=volume,source=pipcache,target=${env.PIP_CACHE_DIR} " +
                                                        "--mount type=volume,source=uv_cache_dir,target=${env.UV_CACHE_DIR}"
                                                ){
                                                 bat(script: 'python -m venv venv && venv\\Scripts\\pip install --disable-pip-version-check uv && venv\\Scripts\\uv export --frozen --only-group dev --no-hashes --format requirements.txt --no-emit-project --no-annotate > requirements-dev.txt')
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
                                                        def image
                                                        checkout scm
                                                        lock("${env.JOB_NAME} - ${env.NODE_NAME}"){
                                                            retry(retryTimes){
                                                                image = docker.build(UUID.randomUUID().toString(), '-f scripts/resources/windows/Dockerfile --build-arg UV_INDEX_URL --build-arg CONAN_CENTER_PROXY_V2_URL --build-arg CHOCOLATEY_SOURCE' + (env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE ? " --build-arg FROM_IMAGE=${env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE} ": ' ') + '.')
                                                            }
                                                        }
                                                        try{
                                                            try{
                                                                checkout scm
                                                                image.inside("--mount type=volume,source=uv_python_install_dir,target=${env.UV_PYTHON_INSTALL_DIR} " +
                                                                             "--mount type=volume,source=pipcache,target=${env.PIP_CACHE_DIR} " +
                                                                             "--mount type=volume,source=uv_cache_dir,target=${env.UV_CACHE_DIR}"
                                                                ){
                                                                    retry(retryTimes){
                                                                        try{
                                                                            bat(label: 'Running Tox',
                                                                                script: """uv python install cpython-${version}
                                                                                           uv export --frozen --only-group dev --no-hashes --format requirements.txt --no-emit-project --no-annotate > requirements-dev.txt
                                                                                           uvx -p ${version} --constraint=requirements-dev.txt --with tox-uv tox run -e ${toxEnv} -vv
                                                                                        """
                                                                            )
                                                                        } catch (e){
                                                                            cleanWs(
                                                                                patterns: [
                                                                                        [pattern: '.tox', type: 'INCLUDE'],
                                                                                    ],
                                                                                notFailBuild: true,
                                                                                deleteDirs: true
                                                                            )
                                                                            throw e;
                                                                        }
                                                                    }
                                                                }
                                                            } finally {
                                                                bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                            }
                                                        } finally{
                                                            if (image){
                                                                bat "docker rmi --force --no-prune ${image.id}"
                                                            }
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
//             environment{
//                 UV_BUILD_CONSTRAINT='requirements-dev.txt'
//             }
            failFast true
            parallel{
                stage('Platform Wheels: Linux'){
                    when {
                        anyOf {
                            equals expected: true, actual: params.INCLUDE_LINUX_X86_64
//                             equals expected: true, actual: params.INCLUDE_LINUX_ARM
                        }
                    }
                    steps{
                        linux_wheels(SUPPORTED_LINUX_VERSIONS, params.TEST_PACKAGES, params, wheelStashes, retryTimes)
                    }
                }
                stage('Platform Wheels: Mac'){
                    when {
                        anyOf {
                            equals expected: true, actual: params.INCLUDE_MACOS_X86_64
                            equals expected: true, actual: params.INCLUDE_MACOS_ARM
                        }
                    }
                    steps{
                        mac_wheels(SUPPORTED_MAC_VERSIONS, params.TEST_PACKAGES, params, wheelStashes, retryTimes)
                    }
                }
                stage('Platform Wheels: Windows'){
                    when {
                        equals expected: true, actual: params.INCLUDE_WINDOWS_X86_64
                    }
                    steps{
                        windows_wheels(SUPPORTED_WINDOWS_VERSIONS, params.TEST_PACKAGES, params, wheelStashes, retryTimes, SHARED_PIP_CACHE_VOLUME_NAME)
                    }
                }
                stage('Source Distribution Package'){
                    stages{
                        stage('Build sdist'){
                            agent {
                                docker{
                                    image 'python'
                                    label 'linux && docker'
                                    args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'
                                  }
                            }
                            environment{
                                PIP_CACHE_DIR='/tmp/pipcache'
                                UV_CACHE_DIR='/tmp/uvcache'
                                UV_TOOL_DIR='/tmp/uvtools'
                                UV_CONSTRAINT='requirements-dev.txt'
                            }
                            steps{
                                script{
                                    try{
                                        sh(
                                            label: 'Setting up uv',
                                            script: 'python3 -m venv venv && venv/bin/pip install --disable-pip-version-check uv && venv/bin/uv export --frozen --only-group dev --no-hashes --format requirements.txt --no-emit-project --no-annotate > $UV_CONSTRAINT'
                                        )
                                        sh(
                                            label: 'Package',
                                            script: './venv/bin/uv build --build-constraints $UV_CONSTRAINT --sdist'
                                        )
                                        sh(
                                            label: 'Twine check',
                                            script: './venv/bin/uvx twine check --strict  dist/*'
                                        )
                                        stash includes: 'dist/*.tar.gz,dist/*.zip', name: 'python sdist'
                                        archiveArtifacts artifacts: 'dist/*.tar.gz,dist/*.zip'
                                    } finally {
                                        sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                    }
                                }
                            }
                        }
                        stage('Test sdist'){
                            when{
                                equals expected: true, actual: params.TEST_PACKAGES
                            }
                            steps{
                                script{
                                    def testSdistStages = [
                                        failFast: true
                                    ]
                                    testSdistStages << SUPPORTED_MAC_VERSIONS.collectEntries{ pythonVersion ->
                                        def selectedArches = []
                                        def allValidArches = ["x86_64", "arm64"]
                                        if(params.INCLUDE_MACOS_X86_64 == true){
                                            selectedArches << "x86_64"
                                        }
                                        if(params.INCLUDE_MACOS_ARM == true){
                                            selectedArches << "arm64"
                                        }
                                        return allValidArches.collectEntries{ arch ->
                                            def newStageName = "Test sdist (MacOS ${arch} - Python ${pythonVersion})"
                                            return [
                                                "${newStageName}": {
                                                    if(selectedArches.contains(arch)){
                                                        stage("Test sdist (MacOS ${arch} - Python ${pythonVersion})"){
                                                            node("mac && python${pythonVersion} && ${arch}"){
                                                                checkout scm
                                                                unstash 'python sdist'
                                                                try{
                                                                    findFiles(glob: 'dist/*.tar.gz').each{
                                                                        sh(label: 'Running Tox',
                                                                           script: """python${pythonVersion} -m venv venv
                                                                                      venv/bin/python -m pip install --disable-pip-version-check uv
                                                                                      uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                                      venv/bin/uvx --constraint requirements-dev.txt --with tox-uv tox run --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv
                                                                                      rm -rf ./.tox
                                                                                      rm -rf ./venv
                                                                                   """
                                                                        )
                                                                    }
                                                                } finally {
                                                                    sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                                }
                                                            }
                                                        }
                                                    } else {
                                                        Utils.markStageSkippedForConditional(newStageName)
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                    testSdistStages << SUPPORTED_WINDOWS_VERSIONS.collectEntries{ pythonVersion ->
                                        def selectedArches = []
                                        def allValidArches = ["x86_64"]
                                        if(params.INCLUDE_WINDOWS_X86_64 == true){
                                            selectedArches << "x86_64"
                                        }
                                        return allValidArches.collectEntries{ arch ->
                                            def newStageName = "Test sdist (Windows ${arch} - Python ${pythonVersion})"
                                            return [
                                                "${newStageName}": {
                                                    stage(newStageName){
                                                        if(selectedArches.contains(arch)){
                                                            retry(retryTimes){
                                                                node("windows && docker && ${arch}"){
                                                                    def dockerImage
                                                                    try{
                                                                        try{
                                                                            checkout scm
                                                                            lock("docker build-${env.NODE_NAME}"){
                                                                                def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                                                                dockerImage = docker.build(dockerImageName, '-f scripts/resources/windows/Dockerfile --build-arg UV_INDEX_URL --build-arg CONAN_CENTER_PROXY_V2_URL --build-arg CHOCOLATEY_SOURCE' + (env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE ? " --build-arg FROM_IMAGE=${env.DEFAULT_DOCKER_DOTNET_SDK_BASE_IMAGE} ": ' ') + '.')
                                                                            }
                                                                            withEnv([
                                                                                'UV_PYTHON_INSTALL_DIR=C:\\Users\\ContainerUser\\Documents\\uvpython',
                                                                                'PIP_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\cache\\pipcache',
                                                                                'UV_CACHE_DIR=C:\\cache\\uvcache'
                                                                            ]){
                                                                                dockerImage.inside(
                                                                                    '--mount type=volume,source=uv_python_install_dir,target=$UV_PYTHON_INSTALL_DIR ' +
                                                                                    '--mount type=volume,source=pipcache,target=$PIP_CACHE_DIR ' +
                                                                                    '--mount type=volume,source=uv_cache_dir,target=$UV_CACHE_DIR'
                                                                                ){
                                                                                    unstash 'python sdist'
                                                                                    findFiles(glob: 'dist/*.tar.gz').each{
                                                                                        powershell(
                                                                                            label: 'Running Tox',
                                                                                            script: """uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                                                       uvx --constraint requirements-dev.txt --with tox-uv tox run --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv
                                                                                                    """
                                                                                        )
                                                                                    }
                                                                                }
                                                                            }
                                                                        } finally {
                                                                            bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                                        }
                                                                    } finally{
                                                                        powershell(
                                                                            label: "Untagging Docker Image used",
                                                                            script: "docker image rm --no-prune ${dockerImage.imageName()}",
                                                                            returnStatus: true
                                                                        )
                                                                    }
                                                                }
                                                            }
                                                        } else {
                                                            Utils.markStageSkippedForConditional(newStageName)
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                    testSdistStages << SUPPORTED_LINUX_VERSIONS.collectEntries{ pythonVersion ->
                                        def selectedArches = []
                                        def allValidArches = [
                                            "x86_64",
                                            // Arm is not current working, mediainfo requires libcurl which fails to build on ARM64
                                            // "arm64"
                                        ]
                                        if(params.INCLUDE_LINUX_X86_64 == true){
                                            selectedArches << "x86_64"
                                        }
//                                         if(params.INCLUDE_LINUX_ARM == true){
//                                             selectedArches << "arm64"
//                                         }
                                        return allValidArches.collectEntries{ arch ->
                                            def newStageName = "Test sdist (Linux ${arch} - Python ${pythonVersion})"
                                            return [
                                                "${newStageName}": {
                                                    stage(newStageName){
                                                        if(selectedArches.contains(arch)){
                                                            node("linux && docker && ${arch}"){
                                                                def dockerImage
                                                                try{
                                                                    try{
                                                                        checkout scm
                                                                        lock("docker build-${env.NODE_NAME}"){
                                                                            dockerImage = docker.build(UUID.randomUUID().toString(), '-f ci/docker/linux/tox/Dockerfile --build-arg PIP_INDEX_URL --build-arg CONAN_CENTER_PROXY_V2_URL .')
                                                                        }
                                                                        withEnv([
                                                                            'PIP_CACHE_DIR=/tmp/pipcache',
                                                                            'UV_TOOL_DIR=/tmp/uvtools',
                                                                            'UV_PYTHON_INSTALL_DIR=/tmp/uvpython',
                                                                            'UV_CACHE_DIR=/tmp/uvcache',
                                                                        ]){
                                                                            dockerImage.inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'){
                                                                                unstash 'python sdist'
                                                                                findFiles(glob: 'dist/*.tar.gz').each{
                                                                                    sh(
                                                                                        label: 'Running Tox',
                                                                                        script: """python3 -m venv venv
                                                                                                   trap "rm -rf venv" EXIT
                                                                                                   venv/bin/pip install --disable-pip-version-check uv
                                                                                                   trap "rm -rf venv && rm -rf .tox" EXIT
                                                                                                   venv/bin/uv export --frozen --only-dev --no-hashes > requirements-dev.txt
                                                                                                   venv/bin/uvx --python-preference system --constraint requirements-dev.txt --with tox-uv  tox run --installpkg ${it.path} --workdir ./.tox -e py${pythonVersion.replace('.', '')}"""
                                                                                        )
                                                                                }
                                                                            }
                                                                        }
                                                                    } finally {
                                                                        sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                                    }
                                                                } finally{
                                                                    if(dockerImage){
                                                                        sh(
                                                                            label: "Untagging Docker Image used",
                                                                            script: "docker image rm --no-prune ${dockerImage.imageName()}",
                                                                            returnStatus: true
                                                                        )
                                                                    }
                                                                }
                                                            }
                                                        } else {
                                                            Utils.markStageSkippedForConditional(newStageName)
                                                        }
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                    parallel(testSdistStages)
                                }
                            }
                        }
                    }
                }
            }
        }
        stage('Deploy'){
            parallel{
                stage('Deploy to pypi') {
                    environment{
                        PIP_CACHE_DIR='/tmp/pipcache'
                        UV_TOOL_DIR='/tmp/uvtools'
                        UV_PYTHON_INSTALL_DIR='/tmp/uvpython'
                        UV_CACHE_DIR='/tmp/uvcache'
                    }
                    agent {
                        docker{
                            image 'python'
                            label 'docker && linux'
                            args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp'
                        }
                    }
                    when{
                        allOf{
                            equals expected: true, actual: params.BUILD_PACKAGES
                            equals expected: true, actual: params.DEPLOY_PYPI
                            expression{
                                try{
                                    node(){
                                        configFileProvider([configFile(fileId: PYPI_CONFIG_ID, variable: 'CONFIG_FILE')]) {
                                            return true
                                        }
                                    }
                                } catch(e){
                                    echo 'PyPi config not found'
                                    return false
                                }
                                return true
                            }
                        }
                        beforeAgent true
                        beforeInput true
                    }
                    options{
                        retry(retryTimes)
                    }
                    input {
                        message 'Upload to pypi server?'
                        parameters {
                            choice(
                                choices: getPypiConfig(PYPI_CONFIG_ID),
                                description: 'Url to the pypi index to upload python packages.',
                                name: 'SERVER_URL'
                            )
                        }
                    }
                    steps{
                        unstash 'python sdist'
                        script{
                            wheelStashes.each{
                                unstash it
                            }
                        }
                         withEnv(
                            [
                                "TWINE_REPOSITORY_URL=${SERVER_URL}",
                            ]
                        ){
                            withCredentials(
                                [
                                    usernamePassword(
                                        credentialsId: 'jenkins-nexus',
                                        passwordVariable: 'TWINE_PASSWORD',
                                        usernameVariable: 'TWINE_USERNAME'
                                    )
                                ]){
                                    sh(
                                        label: 'Uploading to pypi',
                                        script: '''python3 -m venv venv
                                                   trap "rm -rf venv" EXIT
                                                   . ./venv/bin/activate
                                                   pip install --disable-pip-version-check uv
                                                   uvx --constraint=requirements-dev.txt twine upload --disable-progress-bar --non-interactive dist/*
                                                '''
                                    )
                            }
                        }
                    }
                    post{
                        cleanup{
                            cleanWs(
                                deleteDirs: true,
                                patterns: [
                                        [pattern: 'dist/', type: 'INCLUDE']
                                    ]
                            )
                        }
                    }
                }
            }
        }
    }
}