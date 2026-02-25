import org.jenkinsci.plugins.pipeline.modeldefinition.Utils
library identifier: 'JenkinsPythonHelperLibrary@2024.2.0', retriever: modernSCM(
  [$class: 'GitSCMSource',
   remote: 'https://github.com/UIUCLibrary/JenkinsPythonHelperLibrary.git',
   ])

def PYPI_CONFIG_ID = 'pypi_config'

def SHARED_PIP_CACHE_VOLUME_NAME = 'pipcache'

def SUPPORTED_WINDOWS_VERSIONS_NONABI3 = ['3.11',]
def SUPPORTED_WINDOWS_VERSIONS_ABI3 = ['3.12', '3.13', '3.14']

def SUPPORTED_MAC_VERSIONS_NONABI3 = ['3.11']
def SUPPORTED_MAC_VERSIONS_ABI3 = ['3.12', '3.13', '3.14']

def SUPPORTED_LINUX_VERSIONS_NONABI3 = ['3.11']
def SUPPORTED_LINUX_VERSIONS_ABI3 = ['3.12', '3.13', '3.14']

def retryTimes = 1

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

def createWindowUVConfig(){
    def scriptFile = "ci\\scripts\\new-uv-global-config.ps1"
    if(! fileExists(scriptFile)){
        checkout scm
    }
    return powershell(
        label: 'Setting up uv.toml config file',
        script: "& ${scriptFile} \$env:UV_INDEX_URL \$env:UV_EXTRA_INDEX_URL",
        returnStdout: true
    ).trim()
}

def createUnixUvConfig(){

    def scriptFile = 'ci/scripts/create_uv_config.sh'
    if(! fileExists(scriptFile)){
        checkout scm
    }
    return sh(label: 'Setting up uv.toml config file', script: "sh ${scriptFile} " + '$UV_INDEX_URL $UV_EXTRA_INDEX_URL', returnStdout: true).trim()
}
def getUnixLogicalProcessor(){
    return sh(label: 'Getting the total number of logical cores', script: 'grep -c ^processor /proc/cpuinfo', returnStdout: true).trim()
}

def get_linux_nonabi3_wheels_stages(pythonVersions, testPackages, params, wheelStashes, retryTimes){
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
    return pythonVersions.collectEntries{ pythonVersion ->
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
                                                retry(conditions: [agent()], count: 2) {
                                                    node("linux && docker && ${arch}"){
                                                        retry(retryTimes){
                                                            checkout scm
                                                            try{
                                                                def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                                                try{
                                                                    withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                                        sh( script: "scripts/build_linux_wheels.sh --python-version ${pythonVersion} --docker-image-name  ${dockerImageName}")
                                                                    }
                                                                    stash includes: 'dist/*manylinux*.*whl', name: "python${pythonVersion} linux - ${arch} - wheel"
                                                                    wheelStashes << "python${pythonVersion} linux - ${arch} - wheel"
                                                                    archiveArtifacts artifacts: 'dist/*manylinux*.*whl'
                                                                } finally {
                                                                    sh "docker image rm --no-prune ${dockerImageName}"
                                                                }
                                                            } finally{
                                                                sh "${tool(name: 'Default', type: 'git')} clean -dffx"
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                            def testWheelStageName = "Test Wheel (${pythonVersion} Linux ${arch})"
                                            stage(testWheelStageName){
                                                if(testPackages == true){
                                                    retry(conditions: [agent()], count: 2) {
                                                        node("docker && linux && ${arch}"){
                                                            checkout scm
                                                            unstash "python${pythonVersion} linux - ${arch} - wheel"
                                                            try{
                                                                docker.image('python').inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp')
                                                                {
                                                                    withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}", "TOX_UV_PATH=${WORKSPACE}/venv/bin/uv"]){
                                                                        sh(
                                                                            label: 'Testing with tox',
                                                                            script: """python3 -m venv venv
                                                                                       ./venv/bin/pip install --disable-pip-version-check uv
                                                                                       trap "rm -rf venv" EXIT
                                                                                       ./venv/bin/uv run --only-group=tox tox -e py${pythonVersion.replace('.', '')} --installpkg ${findFiles(glob:'dist/*.whl')[0].path} -vv
                                                                                    """
                                                                        )
                                                                    }
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
    }
}

def get_linux_abi3_wheels_stages(abi3PythonVersions, testPackages, params, wheelStashes, retryTimes){
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
    return allValidArches.collectEntries{ arch ->
        def newVersionStage = "Python ABI3 wheel - Linux ${arch}"
        return [
            "${newVersionStage}": {
                stage(newVersionStage) {
                    if(selectedArches.contains(arch)){
                        stage("Build Wheel ABI3 wheel - Linux ${arch})"){
                            retry(conditions: [agent()], count: 2) {
                                node("linux && docker && ${arch}"){
                                    retry(retryTimes){
                                        checkout scm
                                        try{
                                            def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                            try{
                                                withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                    sh( script: "scripts/build_linux_wheels.sh --python-version abi3 --docker-image-name  ${dockerImageName}")
                                                }
                                                stash includes: 'dist/*manylinux*.*whl', name: "python abi3 linux - ${arch} - wheel"
                                                wheelStashes << "python abi3 linux - ${arch} - wheel"
                                                archiveArtifacts artifacts: 'dist/*manylinux*.*whl'
                                            } finally {
                                                sh "docker image rm --no-prune ${dockerImageName}"
                                            }
                                        } finally{
                                            sh "${tool(name: 'Default', type: 'git')} clean -dffx"
                                        }
                                    }
                                }
                            }
                        }
                        stage('Testing Python ABI3 wheel') {
                            if(testPackages != true){
                                Utils.markStageSkippedForConditional('Testing Python ABI3 wheel')
                            } else {
                                parallel([:] << abi3PythonVersions.collectEntries{pythonVersion ->
                                    return [
                                        "Testing abi3 wheel on Linux - Python ${pythonVersion} - ${arch}": {
                                            node("linux && docker && ${arch}"){
                                                checkout scm
                                                try{
                                                    withEnv([
                                                        'PIP_CACHE_DIR=/tmp/pipcache',
                                                        'UV_TOOL_DIR=/tmp/uvtools',
                                                        'UV_PYTHON_INSTALL_DIR=/tmp/uvpython',
                                                        'UV_CACHE_DIR=/tmp/uvcache',
                                                    ]){
                                                        docker.image('python').inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp --tmpfs /.cache:exec') {
                                                            unstash "python abi3 linux - ${arch} - wheel"
                                                            findFiles(glob: 'dist/*manylinux*.*whl').each{
                                                                timeout(60){
                                                                    sh(label: 'Running Tox',
                                                                       script: """python3 -m venv venv
                                                                       ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                                       ./venv/bin/uv run --only-group dev --with tox_uv tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv"""
                                                                    )
                                                                }
                                                            }
                                                        }
                                                    }
                                                } finally {
                                                    sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                }
                                            }
                                        }
                                    ]
                                })
                            }
                        }
                    }
                }
            }
        ]
    }
}

def get_mac_nonabi3_wheel_stages(pythonVersionsNonAbi3, testPackages, params, wheelStashes, retryTimes){
    def selectedArches = []
    def allValidArches = ['arm64', 'x86_64']
    if(params.INCLUDE_MACOS_X86_64 == true){
        selectedArches << 'x86_64'
    }
    if(params.INCLUDE_MACOS == true){
        selectedArches << 'arm64'
    }
    return pythonVersionsNonAbi3.collectEntries{ pythonVersion ->
        [
            "Python ${pythonVersion} - Mac":{
                stage("Python ${pythonVersion} - Mac"){
                    stage("Wheel for Python ${pythonVersion}"){
                        stage('Build MacOS Universal2 Wheel'){
                            node("mac && python${pythonVersion} && arm64"){
                                checkout scm
                                try{
                                    timeout(60){
                                        withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                            sh(label: 'Building wheel', script: "scripts/build_mac_wheel.sh ${pythonVersion}")
                                        }
                                    }
                                    stash includes: 'dist/*.whl', name: "python${pythonVersion} mac wheel"
                                    wheelStashes << "python${pythonVersion} mac wheel"
                                    archiveArtifacts artifacts: 'dist/*.whl'
                                } finally {
                                    sh "${tool(name: 'Default', type: 'git')} clean -dffx"
                                }
                            }
                        }
                        stage('Test Universal2 Wheel'){
                            if(testPackages != true){
                                Utils.markStageSkippedForConditional('Test Universal2 Wheel')
                            }
                            parallel([failFast: true] << allValidArches.collectEntries{arch ->
                                def newWheelStage = "MacOS - Python ${pythonVersion} - ${arch}: wheel"
                                return [
                                    "${newWheelStage}": {
                                        stage(newWheelStage){
                                            if(selectedArches.contains(arch)){
                                                retry(conditions: [agent()], count: 2) {

                                                }
                                                if(testPackages == true){
                                                    stage("Test Wheel (${pythonVersion} MacOS ${arch})"){
                                                        retry(conditions: [agent()], count: 2) {
                                                            node("mac && python${pythonVersion} && ${arch}"){
                                                                checkout scm
                                                                try{
                                                                    withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                                        unstash "python${pythonVersion} mac wheel"
                                                                        findFiles(glob: 'dist/*.whl').each{
                                                                            timeout(60){
                                                                                sh(label: 'Running Tox',
                                                                                   script: """python${pythonVersion} -m venv venv
                                                                                   ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                                                   ./venv/bin/uv run --only-group=tox tox run --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv"""
                                                                                )
                                                                            }
                                                                        }
                                                                    }
                                                                } finally {
                                                                    sh "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                                }
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
                            })
                        }
                    }
                }
            }
        ]
    }
}
def get_mac_abi3_wheel_stages(pythonVersionsTotestAbi3Wheels, testPackages, params, wheelStashes, retryTimes){
    def selectedArches = []
    def allValidArches = ['arm64', 'x86_64']
    if(params.INCLUDE_MACOS_X86_64 == true){
        selectedArches << 'x86_64'
    }
    if(params.INCLUDE_MACOS == true){
        selectedArches << 'arm64'
    }
    def buildStages = [:]
    buildStages['Python ABI3 wheel'] = {
        stage('Python ABI3 wheel') {
            stage('Building Python ABI3 wheel') {
                node('mac && python3 && arm64'){
                    checkout scm
                    timeout(60){
                        try{
                            withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                sh(label: 'Building Python ABI3 wheel', script: "scripts/build_mac_wheel.sh abi3")
                                stash includes: 'dist/*.whl', name: 'python abi3 wheel'
                            }
                        } finally {
                            sh "${tool(name: 'Default', type: 'git')} clean -dffx"
                        }
                    }
                }
            }
            stage('Testing Python ABI3 wheel') {
                if(testPackages != true){
                    Utils.markStageSkippedForConditional('Testing Python ABI3 wheel')
                }
                parallel([:] << allValidArches.collectEntries{arch ->
                    def testingStages = [:]
                    pythonVersionsTotestAbi3Wheels.each{pythonVersion ->
                        def newWheelStage = "Testing ABI3 wheel on MacOS - Python ${pythonVersion} - ${arch}"
                        testingStages[newWheelStage] = {
                            if(testPackages == true && selectedArches.contains(arch)){
                                node("mac && python${pythonVersion} && ${arch}"){
                                    checkout scm
                                    try{
                                        unstash 'python abi3 wheel'
                                        findFiles(glob: 'dist/*.whl').each{
                                            timeout(60){
                                                sh(label: 'Running Tox',
                                                   script: """python${pythonVersion} -m venv venv
                                                   ./venv/bin/python -m pip install --disable-pip-version-check uv
                                                   ./venv/bin/uv run --only-group dev --with tox_uv tox --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv"""
                                                )
                                            }
                                        }
                                    } finally {
                                        sh "${tool(name: 'Default', type: 'git')} clean -dffx"
                                    }
                                }
                            } else {
                                Utils.markStageSkippedForConditional(newWheelStage)
                            }
                        }
                    }

                    return testingStages
                })
            }
        }
    }

    return buildStages
}
def get_windows_nonabi3_wheel_stages(pythonVersionsNonAbi3, testPackages, params, wheelStashes, retryTimes, sharedPipCacheVolumeName){
    return pythonVersionsNonAbi3.collectEntries{ pythonVersion ->
        def newStage = "Python ${pythonVersion} - Windows"
        [
            "${newStage}": {
                stage(newStage){
                    if(params.INCLUDE_WINDOWS_X86_64 == true){
                        stage("Build Wheel (${pythonVersion} Windows)"){
                            retry(conditions: [agent()], count: 2) {
                                node('windows && docker && x86_64'){
                                    def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                                    try{
                                        checkout scm
                                        try{
                                            retry(retryTimes){
                                                try{
                                                    withEnv(["UV_CONFIG_FILE=${createWindowUVConfig()}",]){
                                                        powershell(label: 'Building Wheel for Windows', script: "scripts/build_windows.ps1 -PythonVersion ${pythonVersion} -DockerImageName ${dockerImageName}")
                                                    }
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
                        }
                        def wheelTestingStageName = "Test Wheel (${pythonVersion} Windows)"
                        stage(wheelTestingStageName){
                            if(testPackages == true){
                                retry(conditions: [agent()], count: 2) {
                                    node('windows && docker'){
                                        withEnv([
                                            'PIP_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\pipcache',
                                            'UV_TOOL_DIR=C:\\Users\\ContainerUser\\Documents\\uvtools',
                                            'UV_PYTHON_INSTALL_DIR=C:\\Users\\ContainerUser\\Documents\\uvpython',
                                            'UV_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\uvcache',
                                        ]){
                                            checkout scm
                                            try{
                                                docker.image(env.DEFAULT_PYTHON_DOCKER_IMAGE ? env.DEFAULT_PYTHON_DOCKER_IMAGE: 'python').inside("--mount source=uv_python_install_dir,target=C:\\Users\\ContainerUser\\Documents\\uvpython --mount source=msvc-runtime,target=c:\\msvc_runtime --mount source=${sharedPipCacheVolumeName},target=${env:PIP_CACHE_DIR}"){
                                                    retry(retryTimes){
                                                        try{
                                                            withEnv(["UV_CONFIG_FILE=${createWindowUVConfig()}",]){
                                                                unstash "python${pythonVersion} windows wheel"
                                                                findFiles(glob: 'dist/*.whl').each{
                                                                    bat """python -m pip install --disable-pip-version-check uv
                                                                           uv run --only-group=tox -p ${pythonVersion} tox run -e py${pythonVersion.replace('.', '')}  --installpkg ${it.path}
                                                                        """
                                                                }
                                                            }
                                                        } catch (e){
                                                            cleanWs(
                                                                patterns: [
                                                                    [pattern: '.tox/', type: 'INCLUDE'],
                                                                    [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                                ],
                                                                notFailBuild: true,
                                                                deleteDirs: true
                                                            )
                                                            throw e
                                                        }
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
    }
}
def get_windows_abi3_wheel_stages(pythonVersionsAbi3, testPackages, params, wheelStashes, retryTimes, sharedPipCacheVolumeName){
    def buildStages = [:]
    buildStages['Python ABI3 wheel'] = {
        stage('Python ABI3 wheel') {
            stage('Building Python ABI3 wheel') {
                retry(conditions: [agent()], count: 2) {
                    node('windows && docker && x86_64'){
                        def dockerImageName = "${currentBuild.fullProjectName}_${UUID.randomUUID().toString()}".replaceAll("-", "_").replaceAll('/', "_").replaceAll(' ', "").toLowerCase()
                        try{
                            checkout scm
                            try{
                                retry(retryTimes){
                                    try{
                                        withEnv([
                                            "UV_CONFIG_FILE=${createWindowUVConfig()}",
                                            'SETUPTOOLS_BUILD_TEMP_DIR=c:\\temp\\build',
                                        ]){
                                            powershell(label: 'Building Wheel for Windows', script: "scripts/build_windows.ps1 -PythonVersion abi3 -DockerImageName ${dockerImageName}")
                                        }
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
                                stash includes: 'dist/*.whl', name: 'python abi3 windows wheel'
                                wheelStashes << 'python abi3 windows wheel'
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
            }
            stage('Testing Python ABI3 wheel') {
                if(testPackages != true){
                    Utils.markStageSkippedForConditional('Testing Python ABI3 wheel')
                } else {
                    parallel([failFast: true] << pythonVersionsAbi3.collectEntries{pythonVersion ->
                        return [
                            "Testing abi3 wheel on Windows - Python ${pythonVersion}": {
                                node('windows && docker && x86_64'){
                                    retry(conditions: [agent()], count: 2) {
                                        node('windows && docker'){
                                            withEnv([
                                                'PIP_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\pipcache',
                                                'UV_TOOL_DIR=C:\\Users\\ContainerUser\\Documents\\uvtools',
                                                'UV_PYTHON_INSTALL_DIR=C:\\Users\\ContainerUser\\Documents\\uvpython',
                                                'UV_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\uvcache',
                                            ]){
                                                checkout scm
                                                try{
                                                    docker.image(env.DEFAULT_PYTHON_DOCKER_IMAGE ? env.DEFAULT_PYTHON_DOCKER_IMAGE: 'python').inside("--mount source=uv_python_install_dir,target=C:\\Users\\ContainerUser\\Documents\\uvpython --mount source=msvc-runtime,target=c:\\msvc_runtime --mount source=${sharedPipCacheVolumeName},target=${env:PIP_CACHE_DIR}"){
                                                        retry(retryTimes){
                                                            try{
                                                                withEnv(["UV_CONFIG_FILE=${createWindowUVConfig()}",]){
                                                                    unstash 'python abi3 windows wheel'
                                                                    findFiles(glob: 'dist/*.whl').each{
                                                                        bat """python -m pip install --disable-pip-version-check uv
                                                                               uv run --python ${pythonVersion}+gil --only-group=tox tox run -e py${pythonVersion.replace('.', '')}  --installpkg ${it.path}
                                                                            """
                                                                    }
                                                                }
                                                            } catch (e){
                                                                cleanWs(
                                                                    patterns: [
                                                                        [pattern: '.tox/', type: 'INCLUDE'],
                                                                        [pattern: '**/__pycache__/', type: 'INCLUDE'],
                                                                    ],
                                                                    notFailBuild: true,
                                                                    deleteDirs: true
                                                                )
                                                                throw e
                                                            }
                                                        }
                                                    }
                                                } finally {
                                                    bat "${tool(name: 'Default', type: 'git')} clean -dfx"
                                                }
                                            }
                                        }
                                    }
                                }
                            }
                        ]
                    })
                }
            }
        }
    }
    return buildStages

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
        booleanParam(name: 'INCLUDE_MACOS', defaultValue: false, description: 'Include ARM(m1) architecture for Mac')
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
                            args '--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp -e UV_PROJECT_ENVIRONMENT=/cache/uv_project_environment --tmpfs /cache:exec'
                            additionalBuildArgs '--build-arg CONAN_CENTER_PROXY_V2_URL'
                        }
                    }
                    environment{
                        PIP_CACHE_DIR='/tmp/pipcache'
                        UV_TOOL_DIR='/tmp/uvtools'
                        UV_PYTHON_INSTALL_DIR='/tmp/uvpython'
                        UV_CACHE_DIR='/tmp/uvcache'
                        UV_CONFIG_FILE="${createUnixUvConfig()}"
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
                                                        script: 'uv sync --frozen --group=ci -v'
                                                   )
                                                } catch(e){
                                                    cleanWs(
                                                        patterns: [
                                                                [pattern: '.venv/', type: 'INCLUDE'],
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
                                                       uv run setup.py build_ext --inplace --build-temp build/temp  --build-lib build/lib --debug
                                                       '''
                                        )
                                    }
                                    post{
                                        failure{
                                            sh 'uv pip list'
                                        }
                                    }
                                }
                            }
                        }
                        stage('Sphinx Documentation'){
                            steps {
                                sh(
                                    label: 'Building docs',
                                    script: 'uv run sphinx-build -b html docs/source build/docs/html -d build/docs/doctrees -v -w logs/build_sphinx.log -W --keep-going'
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
                                            sh 'clang-tidy src/uiucprescon/pymediaconch/pymediaconch.cpp -- $(uv run -m nanobind --include_dir) -Ibuild/temp/include | tee logs/clang-tidy.log'
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
                                                       uv run coverage run --parallel-mode --source=src,tests -m pytest --junitxml=$PYTEST_JUNIT_XML --basetemp=/tmp/pytest -o pythonpath=src
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
                                                script: 'uv run -m sphinx -b doctest docs/source build/docs -d build/docs/doctrees --no-color --builder=linkcheck --fail-on-warning -w logs/linkcheck.log'
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
                                            script: 'uv run coverage run --parallel-mode --source=src -m sphinx -b doctest docs/source dist/docs/html -d build/docs/doctrees --no-color -w logs/doctest.txt'
                                            )
                                    }
                                    post{
                                        always {
                                            recordIssues(tools: [sphinxBuild(id: 'doctest', name: 'Doctest', pattern: 'logs/doctest.txt')])
                                        }
                                    }
                                }
                                stage('Audit uv.lock File'){
                                    options{
                                        timeout(5)
                                    }
                                    steps{
                                        catchError(
                                            buildResult: 'UNSTABLE',
                                            message: 'uv-secure found issues. uv.lock might need to updated'
                                        ) {
                                            sh 'uvx uv-secure --disable-cache uv.lock'
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
                                                script: 'uv run mypy -p uiucprescon.pymediaconch --html-report reports/mypy/html > logs/mypy.log'
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
                                                  uv run coverage combine
                                                  uv run coverage xml -o ./reports/coverage/coverage-python.xml
                                                  uv run --isolated --only-group=ci gcovr --root . --print-summary --keep --json -o reports/coverage/coverage_cpp.json build
                                                  uv run --isolated --only-group=ci gcovr --add-tracefile reports/coverage/coverage_cpp.json --keep --print-summary --xml -o reports/coverage/coverage_cpp.xml
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
                                            docker.image('ghcr.io/astral-sh/uv:debian').inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp --tmpfs /.local/bin:exec --tmpfs /tox_workdir:exec -e TOX_WORK_DIR=/tox_workdir/.tox -e UV_PROJECT_ENVIRONMENT=/tox_workdir/.venv'){
                                                withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                    envs = sh(
                                                        label: 'Get tox environments',
                                                        script: 'uv run --quiet --only-group=tox tox list -d --no-desc',
                                                        returnStdout: true,
                                                    ).trim().split('\n')
                                                }
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
                                                                image.inside('--mount source=python-tmp-uiucpreson-pymediaconch,target=/tmp --tmpfs /.local/share/uv/credentials --tmpfs /cache:exec -e TOX_WORK_DIR=/cache/tox -e UV_PROJECT_ENVIRONMENT=/cache/uv_project_environment') {
                                                                    withEnv([
                                                                        "UV_CONFIG_FILE=${createUnixUvConfig()}",
                                                                        "UV_CONCURRENT_BUILDS=${getUnixLogicalProcessor()}",
                                                                        "UV_CONCURRENT_INSTALLS=${getUnixLogicalProcessor()}",
                                                                        "UV_LOCK_TIMEOUT=600"
                                                                        ]){
                                                                        retry(retryTimes){
                                                                            try{
                                                                                sh( label: 'Running Tox',
                                                                                    script: "uv run --only-group=tox --python-preference system tox run -e ${toxEnv} -vv"
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
                                 UV_CACHE_DIR='C:\\Users\\ContainerUser\\Documents\\cache\\uvcache'
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
                                                 withEnv(["UV_CONFIG_FILE=${createWindowUVConfig()}"]){
                                                     bat(script: 'python -m venv venv && venv\\Scripts\\pip install --disable-pip-version-check uv')
                                                     envs = bat(
                                                         label: 'Get tox environments',
                                                         script: '@.\\venv\\Scripts\\uv run --quiet --only-group=tox tox list -d --no-desc --runner=virtualenv',
                                                         returnStdout: true,
                                                     ).trim().split('\r\n')
                                                 }
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
                                                                image.inside("--mount type=volume,source=uv_python_install_dir,target=${env.UV_PYTHON_INSTALL_DIR} " +
                                                                             "--mount type=volume,source=pipcache,target=${env.PIP_CACHE_DIR} " +
                                                                             "--mount type=volume,source=uv_cache_dir,target=${env.UV_CACHE_DIR}"
                                                                ){
                                                                    retry(retryTimes){
                                                                        try{
                                                                            withEnv([
                                                                            "UV_CONFIG_FILE=${createWindowUVConfig()}",
                                                                            'SETUPTOOLS_BUILD_TEMP_DIR=c:\\temp\\build',
                                                                            'DISTUTILS_DEBUG=1',
                                                                            ]){
                                                                                bat(label: 'Running Tox',
                                                                                    script: """uv python install cpython-${version}
                                                                                               uv run --only-group=tox tox run -e ${toxEnv} -vv
                                                                                            """
                                                                                )
                                                                            }
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
            failFast true
            parallel{
                stage('Platform Wheels: Linux'){
                    when {
                        anyOf {
                            equals expected: true, actual: params.INCLUDE_LINUX_X86_64
                            equals expected: true, actual: params.INCLUDE_LINUX_ARM
                        }
                    }
                    steps{
                        script{
                            parallel(
                                [failFast: true] +
                                get_linux_abi3_wheels_stages(SUPPORTED_LINUX_VERSIONS_ABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes) +
                                get_linux_nonabi3_wheels_stages(SUPPORTED_LINUX_VERSIONS_NONABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes)
                            )
                        }
                    }
                }
                stage('Platform Wheels: Mac'){
                    when {
                        anyOf {
                            equals expected: true, actual: params.INCLUDE_MACOS_X86_64
                            equals expected: true, actual: params.INCLUDE_MACOS
                        }
                    }
                    steps{
                        script{
                            parallel(
                                [failFast: true] +
                                get_mac_nonabi3_wheel_stages(SUPPORTED_MAC_VERSIONS_NONABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes) +
                                get_mac_abi3_wheel_stages(SUPPORTED_MAC_VERSIONS_ABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes)
                            )
                        }
                    }
                }
                stage('Platform Wheels: Windows'){
                    when {
                        equals expected: true, actual: params.INCLUDE_WINDOWS_X86_64
                    }
                    steps{
                        script{
                            parallel(
                                [failFast: true] +
                                get_windows_nonabi3_wheel_stages(SUPPORTED_WINDOWS_VERSIONS_NONABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes, SHARED_PIP_CACHE_VOLUME_NAME) +
                                get_windows_abi3_wheel_stages(SUPPORTED_WINDOWS_VERSIONS_ABI3, params.TEST_PACKAGES, params, wheelStashes, retryTimes, SHARED_PIP_CACHE_VOLUME_NAME)
                            )
                        }
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
                                UV_CONFIG_FILE="${createUnixUvConfig()}"
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
                                            script: './venv/bin/uv run --only-group=deploy twine check --strict  dist/*'
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
                                    testSdistStages << (SUPPORTED_MAC_VERSIONS_NONABI3 + SUPPORTED_MAC_VERSIONS_ABI3).collectEntries{ pythonVersion ->
                                        def selectedArches = []
                                        def allValidArches = ["x86_64", "arm64"]
                                        if(params.INCLUDE_MACOS_X86_64 == true){
                                            selectedArches << "x86_64"
                                        }
                                        if(params.INCLUDE_MACOS == true){
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
                                                                withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                                    unstash 'python sdist'
                                                                    try{
                                                                        findFiles(glob: 'dist/*.tar.gz').each{
                                                                            sh(label: 'Running Tox',
                                                                               script: """python${pythonVersion} -m venv venv
                                                                                          venv/bin/python -m pip install --disable-pip-version-check uv
                                                                                          venv/bin/uv run --only-group=tox tox run --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv
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
                                                        }
                                                    } else {
                                                        Utils.markStageSkippedForConditional(newStageName)
                                                    }
                                                }
                                            ]
                                        }
                                    }
                                    testSdistStages << (SUPPORTED_WINDOWS_VERSIONS_NONABI3 + SUPPORTED_WINDOWS_VERSIONS_ABI3).collectEntries{ pythonVersion ->
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
                                                                                'UV_PYTHON_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\uvpython',
                                                                                'PIP_CACHE_DIR=C:\\Users\\ContainerUser\\Documents\\cache\\pipcache',
                                                                                'UV_CACHE_DIR=C:\\cache\\uvcache',
                                                                                'SETUPTOOLS_BUILD_TEMP_DIR=c:\\temp\\build',
                                                                                "UV_CONFIG_FILE=${createWindowUVConfig()}"
                                                                            ]){
                                                                                dockerImage.inside(
                                                                                    '--mount type=volume,source=uv_python_cache_dir,target=$UV_PYTHON_CACHE_DIR ' +
                                                                                    '--mount type=volume,source=pipcache,target=$PIP_CACHE_DIR ' +
                                                                                    '--mount type=volume,source=uv_cache_dir,target=$UV_CACHE_DIR'
                                                                                ){
                                                                                    unstash 'python sdist'
                                                                                    bat "uv python install cpython-${pythonVersion}"
                                                                                    findFiles(glob: 'dist/*.tar.gz').each{
                                                                                        powershell(
                                                                                            label: 'Running Tox',
                                                                                            script: "uv run --python ${pythonVersion}+gil --only-group=tox tox run --installpkg ${it.path} -e py${pythonVersion.replace('.', '')} -vv"
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
                                    testSdistStages << (SUPPORTED_LINUX_VERSIONS_NONABI3 + SUPPORTED_LINUX_VERSIONS_ABI3).collectEntries{ pythonVersion ->
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
                                                                                withEnv(["UV_CONFIG_FILE=${createUnixUvConfig()}",]){
                                                                                    unstash 'python sdist'
                                                                                    findFiles(glob: 'dist/*.tar.gz').each{
                                                                                        sh(
                                                                                            label: 'Running Tox',
                                                                                            script: """python3 -m venv venv
                                                                                                       trap "rm -rf venv" EXIT
                                                                                                       venv/bin/pip install --disable-pip-version-check uv
                                                                                                       trap "rm -rf venv && rm -rf .tox" EXIT
                                                                                                       venv/bin/uv run --python-preference system --only-group=tox tox run --installpkg ${it.path} --workdir ./.tox -e py${pythonVersion.replace('.', '')} -vv"""
                                                                                            )
                                                                                    }
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
                                                   ./venv/bin/pip install --disable-pip-version-check uv
                                                   . ./venv/bin/activate
                                                   uv sync --active --frozen --only-group deploy
                                                   upload --disable-progress-bar --non-interactive dist/*
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