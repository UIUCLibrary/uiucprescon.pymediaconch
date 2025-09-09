## v0.1.1 (2025-09-09)

### Feat

- MediaConch class now accepts keyword arguments for all public methods
- packaged with Type information

### Fix

- add __init__.py

## v0.1.0 (2025-08-28)

### Feat

- enable free threaded python support

### Fix

- correctly link the lib

### Refactor

- split up linux build script into two scripts
- split build_windows.ps1 to have another script inside the container that handle build logic
- split build_linux_wheels.sh to have another script inside the container that handle build logic
