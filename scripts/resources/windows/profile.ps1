function Build-Wheel {
    [CmdletBinding()]
    param (
        [string]$SourceDirectory,
        [string]$OutputDirectory,
        [string]$PythonVersion
    )

    function New-ShadowCopy {
        [CmdletBinding()]
        param (
            [string]$Source,
            [string]$Destination
        )
        Write-Verbose 'New-ShadowCopy'
        if (Test-Path -Path $Destination) {
            Write-Verbose "Removing $Destination"
            Remove-Item -Path $Destination -Recurse -Force
        }
        Write-Verbose "Creating $Destination"
        New-Item -ItemType Directory -Path $Destination | Out-Null

        Write-Verbose "Listing $Source"
        Get-ChildItem -Path $Source -Recurse | ForEach-Object {
            if ($_.Name -eq '__pycache__') {
                Write-Verbose "Skipping: $($_.FullName)"
                return
            }
            if ($_.Extension -eq '.pyc'){
                Write-Verbose "Skipping: $($_.FullName)"
                return
            }
            if ($_.PSIsContainer) {
                return
            }
            Push-Location $Source
            try{
                $relPath = Resolve-Path $_.FullName -Relative
            } finally {
                Pop-Location
            }
            $linkPath = Join-Path -Path $Destination -ChildPath $relPath
            Write-Verbose "Creating symlink for $relPath in $Destination"

            New-Item -ItemType SymbolicLink -Path $linkPath -Target $_.FullName -Force | Out-Null

        }
    }

    function New-PythonWheel {
        param (
            [string]$Source,
            [string]$Output,
            [string]$PythonVersion,
            [string]$BuildConstraints
        )
        pushd $Source
        try{
            uv build -vv --build-constraints=$BuildConstraints --python=$PythonVersion --wheel --out-dir=$Output --config-setting=conan_cache=C:/Users/ContainerAdministrator/.conan2 $Source
            if ($LASTEXITCODE -ne 0)
            {
                Get-ChildItem -Recurse -Path $Source -FollowSymlink
                throw "Failed to build Python wheel"
            }
        } finally {
            popd
        }
    }

    function FixupPythonWheel {
        param (
            [string]$WheelFile,
            [string]$OutputDirectory,
            [string]$SourceDirectory
        )
        uv run --frozen --only-group=fix-up-wheel --project=$SourceDirectory --isolated delvewheel repair $WheelFile --namespace-pkg uiucprescon.pymediaconch --no-mangle-all --wheel-dir $OutputDirectory
    }

    function Verify-PackageWithTwine{
        param (
            [string]$PackagePath,
            [string]$SourceDirectory
        )
        uv run --frozen --only-group=deploy --project=$SourceDirectory --isolated twine check --strict $PackagePath
        if ($LASTEXITCODE -ne 0)
        {
            throw "Twine check failed for package: $PackagePath"
        }
    }
    Write-Host "Python Version: $PythonVersion"

    Write-Host "Creating shadow copy of source directory..."
    New-ShadowCopy -Source $SourceDirectory -Destination "$env:TEMP\build_src"
    $ConstrainstsFile = "$env:TEMP\constrainsts.txt"

    uv export --only-group=dev --python=$PythonVersion --no-hashes --format requirements.txt --no-emit-project --no-annotate --directory "$env:TEMP\build_src" > $ConstrainstsFile
    Write-Host "Building wheel..."
    New-PythonWheel -Source "$env:TEMP\build_src" -Output "$env:TEMP\wheel_tmp" -PythonVersion $PythonVersion -BuildConstraints $ConstrainstsFile


    foreach ($item in $(Get-ChildItem -Path "$env:TEMP\wheel_tmp" -Filter "*.whl")){
        Verify-PackageWithTwine -PackagePath $item.FullName -SourceDirectory $SourceDirectory
        Write-Host "Fixing up $item"
        FixupPythonWheel -SourceDirectory $SourceDirectory -WheelFile $item.FullName -OutputDirectory $OutputDirectory
    }
    Write-Host "Wheel built successfully and saved to $OutputDirectory"
}
