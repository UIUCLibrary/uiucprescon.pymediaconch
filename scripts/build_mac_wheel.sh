#!/usr/bin/env bash
INSTALLED_UV=$(command -v uv)
DEFAULT_BASE_PYTHON="python3"
REQUIREMENTS_FILE="$(mktemp -d)/constraints.txt"

set -e

verify_package_with_twine() {
  local dist_directory=$1
  echo 'Verifying package with twine'

  if ! uv run --only-group=deploy twine check --strict "${dist_directory}"/*.whl
  then
    echo "Twine check failed. Please fix the issues and try again."
    exit 1
  fi
}

generate_wheel_with_uv(){
    local uv=$1
    local project_root=$2
    local pythonVersion=$3
    local constraints=$4
    local arch=$5

    MACOSX_DEPLOYMENT_TARGET='10.13'
    out_temp_wheels_dir=$(mktemp -d /tmp/python_wheels.XXXXXX)
    output_path="./dist"
    trap 'rm -rf $out_temp_wheels_dir' ERR SIGINT SIGTERM RETURN
    if [[ "$pythonVersion" == 'abi3' ]]; then
        uname=$(uname -m)
        if [[ "$uname" == "x86_64" ]]; then
            pythonVersion="cpython->=3.12+gil-macos-x86_64"
        elif [[ "$uname" == "arm64" ]]; then
            pythonVersion="cpython->=3.12+gil-macos-aarch64"
        else
          pythonVersion="cpython->=3.12+gil-macos"
        fi
    fi
    if [ "$arch" == "universal2" ]; then
        _PYTHON_HOST_PLATFORM="macosx-$MACOSX_DEPLOYMENT_TARGET-universal2"
    elif [ "$arch" == "arm64" ]; then
      _PYTHON_HOST_PLATFORM="macosx-$MACOSX_DEPLOYMENT_TARGET-arm64"
    elif [ "$arch" == "x86_64" ]; then
      _PYTHON_HOST_PLATFORM="macosx-$MACOSX_DEPLOYMENT_TARGET-x86_64"
    else
      echo "unsupported platform type: $arch"
      exit 1
    fi
    _PYTHON_HOST_PLATFORM=$_PYTHON_HOST_PLATFORM MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET $uv build --python="$pythonVersion" --build-constraints "$constraints" --index-strategy=unsafe-best-match --config-setting=arch="$arch" --wheel --out-dir="$out_temp_wheels_dir" "$project_root"
    verify_package_with_twine "$out_temp_wheels_dir"
    search_pattern="$out_temp_wheels_dir/*.whl"
    echo 'Fixing up wheel'
    for file in $search_pattern; do
          results=$("$uv" tool run --python="$pythonVersion" --constraint "$constraints" --from=delocate delocate-listdeps --depending "${file}")
          if [ -n "$results" ]; then
            echo ""
            echo "================================================================================"
            echo "${file} is linked to the following:"
            echo "$results"
            echo ""
            echo "================================================================================"
          else
            file_name=$(basename "$file")
            echo "$file_name is not linked to anything"
          fi
          $uv tool run --python="$pythonVersion" --constraint "$constraints" --from=delocate delocate-wheel -w $output_path --require-archs "$REQUIRED_ARCH" --verbose "${file}"
    done
}

print_usage(){
    echo "Usage: $0 --python-version= [--help]"
}

show_help() {
    print_usage
    echo
    echo "Arguments:"
    echo "  --python-version   The version of Python to generate a wheel for."
    echo "  --platform         build for a specific platform (x86_64, arm64, universal2). If not provided, it will be determined based on the current machine."
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

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --python-version=*)
        if [[ -n "${1#*=}" && "${1#*=}" != --* ]]; then
            version="${1#*=}"
            python_versions+=("$version")
            shift
        else
          echo "Error: --python-version requires a value"
          exit 1
        fi
      ;;
    --python-version)
      shift
      if [[ -n "$1" && "$1" != --* ]]; then
        python_versions+=("$1")
        shift
      else
        echo "Error: --python-version requires a value"
        exit 1
      fi
      ;;
    --platform=*)
      PLATFORM="${1#*=}"
      shift
      ;;
    --platform)
      PLATFORM="$2"
      shift 2
      ;;
    *)
      echo "Unknown argument: $1"
      show_help
      exit 1
      ;;
  esac
done

if [[ -z "$PLATFORM" ]]; then
  # Get the processor type
    processor_type=$(uname -m)
    if [[ "$processor_type" == "x86_64" ]]; then
        PLATFORM="x86_64"
    elif [[ "$processor_type" == "arm64" ]]; then
        PLATFORM="arm64"
    else
        echo "Unsupported processor type: $processor_type"
        exit 1
    fi
fi


# validate arguments
check_args

if [[ ! -f "$INSTALLED_UV" ]]; then
    tmpdir=$(mktemp -d)
    install_temporary_uv "$tmpdir"
    uv=$tmpdir/bin/uv
else
    uv=$INSTALLED_UV
fi
"$uv" export --only-group=build --no-hashes --format requirements.txt --no-emit-project --no-annotate --directory "${project_root}" > "$REQUIREMENTS_FILE"
cat "$REQUIREMENTS_FILE"
for python_version in "${python_versions[@]}"; do
  generate_wheel_with_uv "$uv" "$project_root" "$python_version" "$REQUIREMENTS_FILE" "$PLATFORM"
done

