function Build-Wheel {
    param (
        [string]$SourceDirectory,
        [string]$OutputDirectory,
        [string]$PythonVersion,
        [string]$ConstrainstsFile
    )

    function New-ShadowCopy {
        param (
            [string]$Source,
            [string]$Destination
        )
        if (Test-Path -Path $Destination) {
            Remove-Item -Path $Destination -Recurse -Force
        }
        New-Item -ItemType Directory -Path $Destination | Out-Null
        Get-ChildItem -Path $Source | ForEach-Object {
            $linkPath = Join-Path -Path $Destination -ChildPath $_.Name
            New-Item -ItemType SymbolicLink -Path $linkPath -Target $_.FullName | Out-Null
        }
    }

    function New-PythonWheel {
        param (
            [string]$Source,
            [string]$Output,
            [string]$PythonVersion,
            [string]$BuildConstraints
        )
        uv build --build-constraints=$BuildConstraints --python=$PythonVersion --wheel --out-dir=$Output --config-setting=conan_cache=C:/Users/ContainerAdministrator/.conan2 $Source
        if ($LASTEXITCODE -ne 0)
        {
            throw "Failed to build Python wheel"
        }
    }

    function FixupPythonWheel {
        param (
            [string]$WheelFile,
            [string]$OutputDirectory,
            [string]$ConstraintsFile
        )
        uvx --constraints $ConstraintsFile delvewheel repair $WheelFile --namespace-pkg uiucprescon.pymediaconch --no-mangle-all --wheel-dir $OutputDirectory
    }

    Write-Host "Python Version: $PythonVersion"

    Write-Host "Creating shadow copy of source directory..."
    New-ShadowCopy -Source $SourceDirectory -Destination "$env:TEMP\build_src"

    Write-Host "Building wheel..."
    New-PythonWheel -Source "$env:TEMP\build_src" -Output "$env:TEMP\wheel_tmp" -PythonVersion $PythonVersion -BuildConstraints $ConstrainstsFile

    Write-Host "Fixing up wheel..."
    foreach ($item in $(Get-ChildItem -Path "$env:TEMP\wheel_tmp" -Filter "*.whl")){
        FixupPythonWheel -ConstraintsFile $ConstrainstsFile -WheelFile $item.FullName -OutputDirectory $OutputDirectory
    }
    Write-Host "Wheel built successfully and saved to $OutputDirectory"
}
