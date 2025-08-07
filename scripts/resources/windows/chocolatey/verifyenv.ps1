cmd /S /C 'uv --version'
if ($LASTEXITCODE -ne 0) { throw "Exit code for testing uv is $LASTEXITCODE" }

cmd /S /C 'git --version'
if ($LASTEXITCODE -ne 0) { throw "Exit code for testing git is $LASTEXITCODE" }
