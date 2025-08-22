#!/usr/bin/env bash
INSTALLED_UV=$(command -v uv)
DEFAULT_BASE_PYTHON="python3"
REQUIREMENTS_FILE="requirements-dev.txt"
set -e

verify_package_with_twine() {
  local dist_directory=$1
  local build_constraints=$2
  echo 'Verifying package with twine'

  if ! uvx --build-constraints "${build_constraints}" twine check --strict "${dist_directory}"/*.whl
  then
    echo "Twine check failed. Please fix the issues and try again."
    exit 1
  fi
}

generate_wheel_with_uv(){
    uv=$1
    project_root=$2
    pythonVersion=$3

    # Get the processor type
    processor_type=$(uname -m)

    # Set the compiling variables based on the processor results
    #
    # The values are taken from cibuildwheel source code
    # https://github.com/pypa/cibuildwheel/blob/main/cibuildwheel/macos.py
    #
    # macOS 11 is the first OS with arm64 support, so the wheels
    # have that as a minimum.

    if [ "$processor_type" == "arm64" ]; then
        _PYTHON_HOST_PLATFORM='macosx-11.0-arm64'
        MACOSX_DEPLOYMENT_TARGET='11.0'
        ARCHFLAGS='-arch arm64'
        REQUIRED_ARCH='arm64'
    elif [ "$processor_type" == "x86_64" ]; then
        _PYTHON_HOST_PLATFORM='macosx-10.9-x86_64'
        MACOSX_DEPLOYMENT_TARGET='10.9'
        ARCHFLAGS='-arch x86_64'
        REQUIRED_ARCH='x86_64'
    else
      echo "Unknown processor type: $processor_type"
    fi

    out_temp_wheels_dir=$(mktemp -d /tmp/python_wheels.XXXXXX)
    output_path="./dist"
    trap 'rm -rf $out_temp_wheels_dir' ERR SIGINT SIGTERM RETURN
    UV_INDEX_STRATEGY=unsafe-best-match _PYTHON_HOST_PLATFORM=$_PYTHON_HOST_PLATFORM MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET ARCHFLAGS=$ARCHFLAGS $uv build --python="$pythonVersion" --build-constraints $REQUIREMENTS_FILE --wheel --out-dir="$out_temp_wheels_dir" "$project_root"
    verify_package_with_twine "$out_temp_wheels_dir" "${REQUIREMENTS_FILE}"
    pattern="$out_temp_wheels_dir/*.whl"
    files=( "$pattern" )
    undelocate_wheel="${files[0]}"

    echo ""
    echo "================================================================================"
    echo "${undelocate_wheel} is linked to the following:"
    $uv tool run --python="$pythonVersion" --index-strategy=unsafe-first-match --constraint $REQUIREMENTS_FILE --from=delocate delocate-listdeps --depending "${undelocate_wheel}"
    echo ""
    echo "================================================================================"
    $uv tool run --python="$pythonVersion" --index-strategy=unsafe-first-match --constraint $REQUIREMENTS_FILE --from=delocate delocate-wheel -w $output_path --require-archs "$REQUIRED_ARCH" --verbose "$undelocate_wheel"
}

print_usage(){
    echo "Usage: $0 python_version [--help]"
}

show_help() {
    print_usage
    echo
    echo "Arguments:"
    echo "  python_version   The version of Python to generate a wheel for."
    echo
    echo "Options:"
    echo "  --help           Display this help message and exit."
}

install_temporary_uv(){
    venvPath=$1
    $DEFAULT_BASE_PYTHON -m venv "$venvPath"
    trap 'rm -rf $venvPath' EXIT
    "$venvPath"/bin/pip install --disable-pip-version-check uv
}

check_args(){
    if [[ -f "$project_root" ]]; then
        echo "error: project_root should point to a directory not a file"
        print_usage
        exit
    fi
    if [[ ! -f "$project_root/pyproject.toml" ]]; then
        echo "error: $project_root contains no pyproject.toml"
        exit
    fi
}

# Check if the help flag is provided
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

scriptDir=$(dirname "${BASH_SOURCE[0]}")
# Assign the project_root argument to a variable
project_root=$(realpath "$scriptDir/..")
python_version=$1

# validate arguments
check_args

if [[ ! -f "$INSTALLED_UV" ]]; then
    tmpdir=$(mktemp -d)
    install_temporary_uv "$tmpdir"
    uv=$tmpdir/bin/uv
else
    uv=$INSTALLED_UV
fi

generate_wheel_with_uv "$uv" "$project_root" "$python_version"
