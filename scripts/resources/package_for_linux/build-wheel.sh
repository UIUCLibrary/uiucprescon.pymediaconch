#!/usr/bin/env bash

set -e

WORKSPACE="/workspace"

SKIP_DIRS_NAMED=(\
    '.git' \
    '.idea' \
    '.mypy_cache' \
    '.pytest_cache' \
    '.ruff_cache' \
    '.tox' \
    'venv' \
    'reports' \
    '__pycache__' \
    'wheelhouse' \
    'ci' \
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
#  echo "from $source_directory to $container_workspace"
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
  local output_manifest
  output_manifest="$(mktemp)"
  touch output_manifest
  mkdir -p "$dist_directory"
  for python_version in "${python_versions[@]}"; do
      echo "Creating wheel for Python version: $python_version"
      local temp_dir
      temp_dir="$(mktemp -d -t pymediaconch_wheel_XXXXXX)"
      uv build --python="$python_version " --python-preference=system --wheel --build-constraints="$build_constraints" --out-dir="${temp_dir}" "${project_directory}";
      glob_search="${temp_dir}/*.whl"
      echo "searching with ${glob_search}"
      for wheel in $glob_search; do
        echo "Adding $wheel ${dist_directory}/"
        printf "%s\t%s\n" "$(basename "$wheel")" "$python_version" >> "$output_manifest"
#        mv "$wheel" "${dist_directory}/"
      done
      mv "${temp_dir}"/*.whl "${dist_directory}/"
  done
  echo "reading $output_manifest"
  cat "$output_manifest"
  cp "$output_manifest" "${dist_directory}/build_output.tsv"
}


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

fix_up_wheels(){
  local source_directory=$1
  local output_directory=$2
  echo 'Fixing up wheels'
  awk -F'\t' '
  {
      make_temp_dir_command = "mktemp -d -t pymediaconch_wheel_fixed_up_XXXXXX"
      make_temp_dir_command | getline temp_dir
      close(make_temp_dir_command)

      system("auditwheel repair \"" source_directory "/" $1 "\" -w " temp_dir)
      ls_command = "ls -1 " temp_dir "/*.whl"
      while ((ls_command | getline line) > 0) {
          system("cp " line " " output_directory "/")
          get_file_name_command = "basename " line
          get_file_name_command | getline wheel_file
          close(get_file_name_command)
          print "Adding " wheel_file " to " output_tsv
          print wheel_file "\t" $2 "\n" >> output_tsv
      }
      close(ls_command)
  }' source_directory="$source_directory" output_directory="$output_directory" output_tsv="${output_directory}/output.tsv" "$source_directory/build_output.tsv"
}

for arg in "$@"; do
    if [[ "$arg" == "--help" || "$arg" == "-h" ]]; then
    show_help
    exit 0
  fi
done

source_directory="$1"
output_directory="$2"
python_versions_to_use=("${@:3}")

build_constraints=/tmp/constraints.txt
echo "Building wheels for Python versions: ${python_versions_to_use[*]}"
make_shadow_copy "$source_directory" "$WORKSPACE"
uv export --frozen --only-group dev --no-hashes --format requirements.txt --no-emit-project --no-annotate --directory "${WORKSPACE}" > $build_constraints
make_wheels "$WORKSPACE" "/tmp/dist" "${build_constraints}" "${python_versions_to_use[@]}"
verify_package_with_twine "/tmp/dist" "${build_constraints}"
fix_up_wheels "/tmp/dist" "${output_directory}"
#cp "/tmp/dist/output.tsv" "${output_directory}/output.tsv"
echo 'Done'
