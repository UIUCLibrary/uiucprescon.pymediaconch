#!/usr/bin/env bash

set -e
scriptDir=$(dirname "${BASH_SOURCE[0]}")
PROJECT_ROOT=$(realpath "$scriptDir/..")
DEFAULT_PYTHON_VERSION="3.13"
DOCKERFILE=$(realpath "$scriptDir/resources/package_for_linux/Dockerfile")
DEFAULT_DOCKER_IMAGE_NAME="pymediaconch_builder"
OUTPUT_PATH="$PROJECT_ROOT/dist"

arch=$(uname -m)

case "$arch" in
  x86_64|amd64)
    DEFAULT_PLATFORM="linux/amd64"
    ;;
  aarch64|arm64)
    DEFAULT_PLATFORM="linux/arm64"
    ;;
  *)
    echo "Architecture: Unknown ($arch)"
    ;;
esac


generate_wheel(){
    platform=$1
    local docker_image_name_to_use=$2
    local output_path=$3
    local python_versions_to_use=("${@:4}")

    docker build \
        -t "$docker_image_name_to_use" \
        --platform="$platform" \
        -f "$DOCKERFILE" \
        --build-arg CONAN_CENTER_PROXY_V2_URL \
        --build-arg PIP_EXTRA_INDEX_URL \
        --build-arg PIP_INDEX_URL \
        --build-arg UV_EXTRA_INDEX_URL \
        --build-arg UV_INDEX_URL \
        "$PROJECT_ROOT"
    mkdir -p "$output_path"
    docker run --rm \
        --platform="$platform" \
        -v "$PROJECT_ROOT":/project:ro \
        --mount type=bind,src="$(realpath "$output_path")",dst=/dist \
        "$docker_image_name_to_use" \
        build-wheel /project /dist "${python_versions_to_use[@]}"
}

test_wheels(){
    local manifest_tsv=$1
    local wheel_path=$2
    local source_path=$3
    awk -F'\t' '
    {
      if($1 && $2){
        print "Testing "$1 " with tox"
        wheel_outside = wheel_path "/" $1
        wheel_inside = "/test_env/dist/" $1
        system("docker run --user $(id -u):$(id -g) --rm -v " source_path "/tox.ini:/test_env/tox.ini -v " source_path "/pyproject.toml:/test_env/pyproject.toml -v " source_path "/tests/:/test_env/tests/ -v " wheel_outside ":" wheel_inside " --workdir /test_env/ --entrypoint=\"/bin/bash\" python -c \"python -m venv /venv && /venv/bin/pip install --disable-pip-version-check uv && /venv/bin/uvx --with tox-uv tox run -e " $2 " --installpkg " wheel_inside " \" ")
      }
    }
    ' wheel_path="$(realpath "$wheel_path")" source_path="$(realpath "$source_path")" "$manifest_tsv"
}


print_usage(){
    echo "Usage: $0 [--project-root[=PROJECT_ROOT]] [--python-version[=PYTHON_VERSION]] [--help]"
}

show_help() {
  print_usage
  echo
  echo "Arguments:                                                                      "
  echo "  --project-root   : Path to Python project containing pyproject.toml file.     "
  echo "                   Defaults to current directory.                               "
  echo "  --python-version : Version of Python wheel to build. This can be specified    "
  echo "                   multiple times to build for multiple versions.               "
  echo "                   Defaults to \"$DEFAULT_PYTHON_VERSION\".                     "
  echo "  --platform       : Platform to build the wheel for.                           "
  echo "                   Defaults to \"$DEFAULT_PLATFORM\".                           "
  echo "  --docker-image-name                                                           "
  echo "                   : Name of the Docker image to use for building the wheel.    "
  echo "                   Defaults to \"$DEFAULT_DOCKER_IMAGE_NAME\".                  "
  echo "  --help, -h       : Display this help message.                                 "
}


check_args(){
    if [[ -f "$PROJECT_ROOT" ]]; then
        echo "error: PROJECT_ROOT should point to a directory not a file"
        print_usage
        exit 1
    fi
    if [[ ! -f "$PROJECT_ROOT/pyproject.toml" ]]; then
        echo "error: $PROJECT_ROOT contains no pyproject.toml"
        exit 1
    fi

}
# === Main script starts here ===


python_versions=()
# Check if the help flag is provided
for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

verify=0

# Parse optional arguments
while [[ "$#" -gt 0 ]]; do
  case "$1" in
    --project-root=*)
      PROJECT_ROOT="${1#*=}"
      shift
      ;;
    --project-root)
      PROJECT_ROOT="$2"
      shift 2
      ;;
    --verify)
      verify=1
      shift 1
      ;;
    --docker-image-name=*)
      docker_image_name="${1#*=}"
      shift
      ;;
    --docker-image-name)
      docker_image_name="$2"
      shift 2
      ;;
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
  PLATFORM="$DEFAULT_PLATFORM"
fi

# Set default if no versions were specified
if [[ ${#python_versions[@]} -eq 0 ]]; then
    python_versions=("$DEFAULT_PYTHON_VERSION")
fi

if [[ ! -v docker_image_name ]]; then
    docker_image_name=$DEFAULT_DOCKER_IMAGE_NAME
else
  echo "Using '$docker_image_name' for the name of the Docker Image generated to build."
fi
check_args
mkdir -p build
temp_dir="$(mktemp -d build/pymediaconch_wheels_XXXXXX)"
trap 'rm -rf $temp_dir' EXIT

generate_wheel "$PLATFORM" "$docker_image_name" "$temp_dir" "${python_versions[@]}"

if (( verify )); then
  test_wheels "${temp_dir}/output.tsv" "$temp_dir" "$PROJECT_ROOT"
fi

mkdir -p "$OUTPUT_PATH"
mv "${temp_dir}"/*.whl "${OUTPUT_PATH}/"
echo "Built wheel can be found in '$OUTPUT_PATH'"
