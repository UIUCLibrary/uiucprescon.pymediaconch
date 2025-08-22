#!/usr/bin/env bash

set -e

WORKSPACE="/workspace"

SKIP_DIRS_NAMED=(\
    'venv' \
    '.tox' \
    '.git' \
    '.idea' \
    'reports' \
    '.mypy_cache' \
    '__pycache__' \
    'wheelhouse' \
    'ci' \
    '.pytest_cache' \
    'pyMediaConch.egg-info'\
    'uiucprescon.pymediaconch.egg-info'\
    'build' \
    )

REMOVE_FILES_FIRST=(\
  'CMakeUserPresets.json'
  'conan.lock'
  )

make_shadow_copy() {
  local source_directory=$1
  local container_workspace=$2
  echo 'Making a shadow copy to prevent modifying local files'
  echo "from $source_directory to $container_workspace"
  local prune_expr=()
  for name in "${SKIP_DIRS_NAMED[@]}"; do
      prune_expr+=(-name "$name" -type d -prune -o);
  done
  mkdir -p "${container_workspace}"
  (
    cd "$source_directory"/ &&
    find . "${prune_expr[@]}" -type d -print | while read -r dir; do
        mkdir -p "${container_workspace}/$dir"
    done
    find . "${prune_expr[@]}" \( -type f -o -type l \) -print | while read -r file; do
        echo "$file"
        ln -sf "$source_directory/$file" "${container_workspace}/$file"
    done
  )

  for f in "${REMOVE_FILES_FIRST[@]}"; do
      OFFENDING_FILE=${container_workspace}/$f
      if [ -f "$OFFENDING_FILE" ]; then
        echo "Removing copy from temporary working path to avoid issues: $f";
        rm "$OFFENDING_FILE";
      fi
  done

  echo 'Removing Python cache files'
  find "${container_workspace}" -type d -name '__pycache__' -exec rm -rf {} +
  find "${container_workspace}" -type f -name '*.pyc' -exec rm -f {} +
}

print_usage(){
    echo "Usage: $0 SOURCE_DIRECTORY OUTPUT_DIRECTORY PYTHON_VERSION [PYTHON_VERSION...] [--help]"
}

show_help() {
  print_usage
  echo "  SOURCE_DIRECTORY   : path to project source code.                             "
  echo "  OUTPUT_DIRECTORY   : path to create wheel files.                              "
  echo "  PYTHON_VERSION     : Python version to generate wheel file for.               "
  echo "                                                                                "
  echo "  --help, -h       : Display this help message.                                 "
}

make_wheels() {
  local project_directory=$1
  local dist_directory=$2
  local build_constraints=$3
  local python_versions=("${@:4}")

  for i in "${python_versions[@]}"; do
      echo "Creating wheel for Python version: $i"
      uv build --python="$i" --python-preference=system --wheel --build-constraints="$build_constraints" --out-dir="${dist_directory}" "${project_directory}";
  done
}

fix_up_wheels(){
  local source_directory=$1
  local output_directory=$2
  echo 'Fixing up wheels'
  auditwheel -v repair "${source_directory}"/*.whl -w "${output_directory}"
  for file in "${output_directory}"/*manylinux*.whl; do
      auditwheel show "$file"
  done
}

for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

source_directory="$1"
output_directory="$2"
build_constraints="$3"
python_versions_to_use=("${@:4}")


if [ ! -f "${source_directory}/$build_constraints" ]; then
  echo "Error: File '$build_constraints' does not exist or is not a regular file."
  exit 1
fi

echo "Building wheels for Python versions: ${python_versions_to_use[*]}"
make_shadow_copy "$source_directory" "$WORKSPACE"

make_wheels "$WORKSPACE" "/tmp/dist" "${WORKSPACE}/${build_constraints}" "${python_versions_to_use[@]}"
fix_up_wheels "/tmp/dist" "${output_directory}"
echo 'Done'
