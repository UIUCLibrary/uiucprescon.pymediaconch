param (
    [string]$DockerImageName = "uiucprescon_pymediaconch_builder",
    [string]$PythonVersion = "3.12"
)

function Build-DockerImage {
    [CmdletBinding()]
    param (
        [string]$DockerfilePath = (Join-Path -Path (Get-Item $PSScriptRoot).FullName -ChildPath "resources/windows/Dockerfile"),
        [string]$ImageName = "uiucprescon_pymediaconch_builder",
        [string]$DockerExec = "docker.exe",
        [string]$DockerIsolation = "process"
    )

    $projectRootDirectory = (Get-Item $PSScriptRoot).Parent.FullName
    $dockerArgsList = @(
        "build",
        "--isolation", $DockerIsolation,
        "--platform windows/amd64",
        "-f", $DockerfilePath,
        "--build-arg CHOCOLATEY_SOURCE",
        "--build-arg UV_INDEX_URL",
        "--build-arg CONAN_CENTER_PROXY_V2_URL",
        "--build-arg UV_CACHE_DIR=c:/users/containeradministrator/appdata/local/uv",
        "-t", $ImageName,
        "."
    )

    $local:dockerBuildProcess = Start-Process -FilePath $DockerExec -WorkingDirectory $projectRootDirectory -ArgumentList $dockerArgsList -NoNewWindow -PassThru -Wait
    if ($local:dockerBuildProcess.ExitCode -ne 0)
    {
        throw "An error creating docker image occurred. Exit code: $($local:dockerBuildProcess.ExitCode)"
    }
}

function Build-Wheel {
    [CmdletBinding()]
    param (
        [string]$DockerImageName = "uiucprescon_pymediaconch_builder",
        [string]$DockerExec = "docker.exe",
        [string]$DockerIsolation = "process",
        [string]$PythonVersion = "3.11",
        [string]$ContainerName = "uiucprescon_pymediaconch_builder"
    )
    $containerDistPath = "c:\dist"
    $projectRootDirectory = (Get-Item $PSScriptRoot).Parent.FullName
    $outputDirectory = Join-Path -Path $projectRootDirectory -ChildPath "dist"
    if (!(Test-Path -Path $outputDirectory)) {
      New-Item -ItemType Directory -Path $outputDirectory | Out-Null
    }
    $containerSourcePath = "c:\src"
    $containerWorkingPath = "c:\build"
    $containerCacheDir = "C:\Users\ContainerUser\Documents\cache"
    $venv = "${containerCacheDir}\venv"

    $UV_TOOL_DIR = "${containerCacheDir}\uvtools"
    $UV_PYTHON_INSTALL_DIR = "${containerCacheDir}\uvpython"

    # This makes a symlink copy of the files mounted in the source. Any changes to the files will not affect outside the container
    $createShallowCopy = "foreach (`$item in `$(Get-ChildItem -Path $containerSourcePath)) { `
        Write-Host `"Creating symlink for `$item.Name`"; `
        `$LinkPath = Join-Path -Path $containerWorkingPath -ChildPath `$item.Name ; `
        New-Item -ItemType SymbolicLink -Path `$LinkPath -Target `$item.FullName | Out-Null `
    }"

    $dockerArgsList = @(
        "run",
        "--isolation", $DockerIsolation,
        "--platform windows/amd64",
        "--rm",
        "--workdir=${containerWorkingPath}",
        "--mount type=volume,source=uvcache,target=C:\Users\ContainerUser\Documents\cache\uvpython",
        "--mount type=volume,source=${ContainerName}Cache,target=${containerCacheDir}",
        "--mount type=bind,source=$(Resolve-Path $projectRootDirectory),target=${containerSourcePath}",
        "--mount type=bind,source=$(Resolve-Path $outputDirectory),target=${containerDistPath}",
        "-e UV_TOOL_DIR=${UV_TOOL_DIR}",
        '--entrypoint', 'powershell',
        $DockerImageName
        "-c",
        ${createShallowCopy};`
        "uv build --build-constraints=${containerSourcePath}\requirements-dev.txt --python=${PythonVersion} --wheel --out-dir=${containerWorkingPath}\dist --config-setting=conan_cache=C:/Users/ContainerAdministrator/.conan2;`
        foreach (`$item in `$(Get-ChildItem -Path $containerSourcePath\dist -Filter `"*.whl`")) {uvx delvewheel repair `$item.FullName --namespace-pkg uiucprescon.pymediaconch --no-mangle-all --wheel-dir ${containerDistPath}}"
    )

    $local:dockerBuildProcess = Start-Process -FilePath $DockerExec -WorkingDirectory $(Get-Item $PSScriptRoot).Parent.FullName -ArgumentList $dockerArgsList -NoNewWindow -PassThru -Wait
    if ($local:dockerBuildProcess.ExitCode -ne 0)
    {
        throw "An error creating docker image occurred. Exit code: $($local:dockerBuildProcess.ExitCode)"
    }
}



Build-DockerImage -ImageName $DockerImageName

Build-Wheel -PythonVersion $PythonVersion -DockerImageName $DockerImageName
