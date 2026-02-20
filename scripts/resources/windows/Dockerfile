# escape=`

# NOTICE: This Dockerfile needs to be built from the root of the repository. If you build it from the same location as this
#         file, it will not work because it needs access to files not in this directory. If you need to build this
#         Dockerfile directly, use the "docker build" command with the "-f ci/docker/windows/Dockerfile" argument.

ARG FROM_IMAGE=mcr.microsoft.com/dotnet/framework/sdk:4.8.1
# Base image to use, this should be of the mcr.microsoft.com/dotnet/framework/sdk family. Use 4.8 if you need to need
# to run on earlier versions of Windows than Windows 11/Windows Server 2022.

ARG VS_INSTALL_PATH="C:\BuildTools"
# Build tools install location for Visual Studio

ARG CONAN_USER_HOME=C:/Users/ContainerAdministrator
# Path where conan data will be stored

ARG CONAN_HOME=${CONAN_USER_HOME}/.conan2

ARG UV_CACHE_DIR=c:/users/containeradministrator/appdata/local/uv
# UV Cache directory. Change this only if you need to override the default location.

ARG PIP_DOWNLOAD_CACHE=c:/users/containeradministrator/appdata/local/pip
# PIP Cache directory. Change this only if you need to override the default location.

ARG CONAN_CENTER_PROXY_V2_URL=https://center2.conan.io
# If you want to use a diffrent remote for Conan, such as a proxy. Set the CONAN_CENTER_PROXY_V2_URL
# Not this is only for building the image. The actual conan center proxy URL is set in the remotes.json file.

ARG CHOCOLATEY_SOURCE=https://chocolatey.org/api/v2
# URL for Chocolatey packages. By default, it will use the official Chocolatey repository.

FROM ${FROM_IMAGE} AS certsgen
RUN certutil -generateSSTFromWU roots.sst

FROM ${FROM_IMAGE} AS base_builder

SHELL ["powershell", "-Command", "$ErrorActionPreference = 'Stop';"]

COPY scripts/resources/windows/msvc/visual_studio_config.json c:/setup/config.vsconfig
COPY scripts/resources/windows/msvc/install_msvc.ps1 c:/scripts/install_msvc.ps1
ARG VS_INSTALL_PATH
ARG VS_VERSION="2022"
ARG VS_DevCmdArguments="-arch=amd64"
ARG VS_DevPowershellArguments='-arch=amd64'
RUN c:/scripts/install_msvc.ps1 -InstallPath ${Env:VS_INSTALL_PATH} -VSConfigFile c:/setup/config.vsconfig -DevCmdArguments ${Env:VS_DevCmdArguments} -DevPowershellArguments ${Env:VS_DevPowershellArguments} -VSVersion ${Env:VS_VERSION}; `
    Write-Host "Note: Exporting this layer can take a while."

ARG CHOCOLATEY_SOURCE
ARG ChocolateyEnvironmentDebug=false
COPY scripts/resources/windows/chocolatey/ c:/choco/
RUN Set-ExecutionPolicy Bypass -Scope Process -Force; `
    $chocolateyDownloadUrl = c:/choco/get_latest_chocolatey_url.ps1 -packageRepo $env:CHOCOLATEY_SOURCE; `
    c:/choco/install.ps1 -ChocolateyDownloadUrl $chocolateyDownloadUrl;`
    . $profile;`
    if( -not ([string]::IsNullOrEmpty($Env:CHOCOLATEY_SOURCE ))) `
    { `
        Write-Host "Adding $env:CHOCOLATEY_SOURCE to chocolatey sources" ; `
        choco source add -n=CHOCOLATEY_SOURCE --priority=1 -s=\"${env:CHOCOLATEY_SOURCE}\"; `
    }; `
    Write-Host "Disabling Showing Download Progress" ; `
    choco feature disable -n=showDownloadProgress ; `
    C:\ProgramData\chocolatey\bin\choco.exe sources ; `
    C:\ProgramData\chocolatey\bin\choco.exe install -y --stoponfirstfailure --no-progress c:/choco/packages.config ;`
    refreshenv ; `
    choco cache remove --confirm;`
    Write-Host "Finished install packages with Chocolatey" ;`
    Write-Host "Verifying installed packages" ;`
    c:/choco/verifyenv.ps1 ;`
    Write-Host "Verifying installed packages - Done"

RUN uv python update-shell

## ==============================================================================
FROM base_builder AS conan_builder
ARG CONAN_HOME
ARG UV_INDEX_URL
COPY ci/docker/shared/conan/remotes.json ${CONAN_HOME}/remotes.json
COPY scripts/resources/windows/conan/profile.ini ${CONAN_HOME}/profiles/default
COPY uv.lock pyproject.toml c:/temp/project/
COPY conanfile.py c:/temp/conanfile.py
COPY conan.lock c:/temp/conan.lock
ENV UV_FROZEN=1 `
    UV_PROJECT=c:/temp/project
ARG CONAN_CENTER_PROXY_V2_URL
RUN uv run --only-group=build conan profile detect --exist-ok ; `
    if (${env:CONAN_CENTER_PROXY_V2_URL} -ne $(Get-Content -Raw -Path ${Env:CONAN_HOME}\remotes.json)) { `
          Copy-Item -Path "${Env:CONAN_HOME}\remotes.json" -Destination "c:\remotes.json" ; `
          uv run --only-group=build conan remote update conan-center --url ${env:CONAN_CENTER_PROXY_V2_URL}; `
    }; `
    uv run --only-group=build conan install c:/temp/ --build missing -pr:b=default ; `
    if ($LASTEXITCODE -ne 0) { `
      throw \"Command 'conan install' failed with exit code: $LASTEXITCODE\"`
    } ;`
    uv run --only-group=build conan cache clean "*" -b --source --build --temp ; `
    uv cache clean --no-progress ; `
    if (${env:CONAN_CENTER_PROXY_V2_URL} -ne $(Get-Content -Raw -Path ${Env:CONAN_HOME}\remotes.json)) { `
      Move-Item -Path "c:\remotes.json" -Destination "${Env:CONAN_HOME}\remotes.json" -Force ;`
    }

# =============================================================================
FROM base_builder
RUN New-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -PropertyType DWORD -Force
COPY --from=certsgen c:/roots.sst roots.sst
RUN certutil -addstore -f root roots.sst ; `
    del roots.sst
ARG CONAN_USER_HOME
ARG CONAN_HOME
COPY --from=conan_builder ${CONAN_HOME}/ ${CONAN_HOME}/
ENV CONAN_USER_HOME=${CONAN_USER_HOME}
COPY scripts/resources/windows/profile.ps1 C:/Windows/System32/WindowsPowerShell/v1.0/profile.ps1
