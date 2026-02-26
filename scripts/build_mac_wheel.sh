#!/usr/bin/env bash
INSTALLED_UV=$(command -v uv)
DEFAULT_BASE_PYTHON="python3"
REQUIREMENTS_FILE="$(mktemp -d)/constraints.txt"
MINIMUM_FOR_ABI3="3.12"
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
    uv=$1
    project_root=$2
    pythonVersion=$3
    constraints=$4

    # Get the processor type
    processor_type=$(uname -m)
    MACOSX_DEPLOYMENT_TARGET='10.13'

    out_temp_wheels_dir=$(mktemp -d /tmp/python_wheels.XXXXXX)
    output_path="./dist"
    trap 'rm -rf $out_temp_wheels_dir' ERR SIGINT SIGTERM RETURN
    MACOSX_DEPLOYMENT_TARGET=$MACOSX_DEPLOYMENT_TARGET $uv build --python="$pythonVersion" --build-constraints "$constraints" --wheel --out-dir="$out_temp_wheels_dir" "$project_root"
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
if [[ "$python_version" == 'abi3' ]]; then
    python_version="$MINIMUM_FOR_ABI3"
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
generate_wheel_with_uv "$uv" "$project_root" "$python_version" "$REQUIREMENTS_FILE"
