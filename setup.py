import functools
import os.path
import pathlib
import platform
import shutil

from pybind11.setup_helpers import Pybind11Extension
from uiucprescon.build.pybind11_builder import BuildPybind11Extension
from uiucprescon.build.conan.files import read_conan_build_info_json, get_library_metadata_from_build_info_json
from uiucprescon.build import conan_libs
from setuptools import setup
import cmake
import json

MEDIACONCH_EXTENSION = "uiucprescon.pymediaconch.mediaconch"
def locate_conan_build_info_json(build_temp):

    build_locations = [
        build_temp,
        os.path.join(build_temp, "conan"),
        os.path.join(build_temp, "conan", "Release"),
        os.path.join(build_temp, "Release"),
    ]
    for location in build_locations:
        build_info = os.path.join(location, "conan_build_info.json")
        if os.path.exists(build_info):
            return build_info
    else:
        raise FileNotFoundError(
            f"conan_build_info.json not found, searched {*build_locations,}"
        )
def add_conan_build_info(core_ext, build_temp, library_name=None):

    with open(locate_conan_build_info_json(build_temp), 'r', encoding="utf-8") as f:
        build_info = get_library_metadata_from_build_info_json(library_name, f)
        # build_info = read_conan_build_info_json(f)
        # breakpoint()

    for lib in build_info.libs:
        if lib not in core_ext.libraries:
            core_ext.libraries.append(lib)

    for path in reversed(build_info.lib_dirs):
        if path not in core_ext.libraries:
            core_ext.library_dirs.insert(0, path)
    for macro in build_info.definitions:
        if macro not in core_ext.define_macros:
            core_ext.define_macros.append(macro)

    return core_ext

def get_binary_directory(cmake_presets_json, config_preset):
    """
    Get the binary directory from the CMakePresets.json file.
    """
    import json
    with open(cmake_presets_json, 'r', encoding='utf-8') as f:
        presets = json.load(f)
    for preset in presets.get('configurePresets', []):
        if preset.get('name') == config_preset:
            if 'binaryDir' in preset:
                return preset['binaryDir']
    raise ValueError(f"Binary directory not found in CMakePresets.json for preset: {config_preset}")


def find_best_config_preset(cmake_presets_json):
    """
    Find the best configuration preset from the CMakePresets.json file.
    """

    with open(cmake_presets_json, 'r', encoding='utf-8') as f:
        presets = json.load(f)
    for preset in presets.get('configurePresets', []):
        if preset.get('hidden', False):
            continue
        if preset.get('name') == "conan-release":
            return preset['name']
        if preset.get('name') == "conan-default":
            return preset['name']
    raise ValueError("No suitable configuration preset found in CMakePresets.json")

def find_config_preset_toolchain(cmake_presets_json, config_preset):
    """
    Find the toolchain file for the given configuration preset in the CMakePresets.json file.
    """
    with open(cmake_presets_json, 'r', encoding='utf-8') as f:
        presets = json.load(f)
    for preset in presets.get('configurePresets', []):
        if preset.get('hidden', False):
            continue
        if preset.get('name') == config_preset:
            return preset.get('toolchainFile')
    raise ValueError(f"Preset not found in CMakePresets.json: {config_preset}")

def configure_pymediaconch(builder, ext):
    cmake_exec = shutil.which("cmake", path=cmake.CMAKE_BIN_DIR)
    if cmake_exec is None:
        raise FileNotFoundError("CMake executable not found. This should have been installed pep517 build dependencies.")
    assert os.path.exists('CMakeUserPresets.json')
    cmake_presets_json = builder.locate_cmake_presets_json()

    cmake_fetchcontent_base_dir = os.path.join(builder.build_temp, "deps")
    config_preset = find_best_config_preset(cmake_presets_json)
    build_preset = "conan-release"
    build_dir = os.path.join(builder.build_temp, "mediaconchlib")
    conan_toolchain_file = find_config_preset_toolchain(cmake_presets_json, config_preset)
    conan_binary_dir = get_binary_directory(cmake_presets_json, config_preset)
    if all([conan_binary_dir, conan_toolchain_file]):
        toolchain_file = os.path.join(conan_binary_dir, conan_toolchain_file)
        if os.path.exists(toolchain_file):
            toolchain_file = os.path.relpath(toolchain_file, ".")
        else:
            toolchain_file = None

    else:
        toolchain_file = None
    installed_prefix = builder.build_temp
    config_cmd = [
        cmake_exec,
        "-DCMAKE_POLICY_DEFAULT_CMP0091:STRING=NEW",
        "-DMEDIACONCH_WITH_SQLITE=No",
        f"-DCMAKE_TOOLCHAIN_FILE={toolchain_file}" if toolchain_file else "",
        f"-DFETCHCONTENT_BASE_DIR={cmake_fetchcontent_base_dir}",
        f'-DCMAKE_INSTALL_PREFIX={installed_prefix}',
        f'-DCMAKE_POSITION_INDEPENDENT_CODE=true',
        "-B", build_dir,
        f"-DCMAKE_BUILD_TYPE={'Debug' if builder.debug else 'Release'}"
    ]
    try:
        builder.spawn(config_cmd)
    except Exception as e:
        raise ValueError(f"cmake command failed during config. Used command: {' '.join(config_cmd)}") from e
    build_cmd = [
        cmake_exec,
        "--build", build_dir,
        "--target", "MediaConchLib",
        "--config", "Debug" if builder.debug else "Release",
    ]
    try:
        builder.spawn(build_cmd)
    except Exception as e:
        raise ValueError(f"cmake command failed during build. Used command: {' '.join(build_cmd)}") from e

    install_command = [
        cmake_exec,
        "--build", build_dir,
        "--config", "Debug" if builder.debug else "Release",
        "--target", "install"
    ]
    try:
        builder.spawn(install_command)
    except Exception as e:
        raise ValueError(f"cmake command failed during install. Used command: {' '.join(install_command)}") from e

    ext.include_dirs.append(os.path.join(installed_prefix, "include"))
    ext.libraries.append("mediaconch")

    ext.library_dirs.append(os.path.join(installed_prefix, "lib"))
    build_conan_cmd = builder.get_finalized_command("build_conan")

    add_conan_build_info(ext, builder.get_finalized_command("build_conan").build_temp)
    conan_libs.update_extension3(ext, functools.partial(conan_libs.match_libs,  build_path=build_conan_cmd.build_temp))
    if builder.compiler.compiler_type == 'msvc':
        ext.libraries += [
            # shell32 is needed because SHGetKnownFolderPath is called in Core::get_local_config_path() in Core.cpp
            "shell32",
            # ole32 is needed because CoTaskMemFree() is called in Core::get_local_config_path() in Core.cpp
            "ole32",
        ]
    # Remove the overlap
    libs = []
    for lib in ext.libraries:
        if lib in libs:
            continue
        libs.append(lib)
    ext.libraries = libs

    include_dirs = []
    for include_dir in ext.include_dirs:
        if include_dir in include_dirs:
            continue
        include_dirs.append(include_dir)
    ext.include_dirs = include_dirs


class BuildExtension(BuildPybind11Extension):
    def locate_cmake_presets_json(self):
        """
        Locate the CMakePresets.json file directory.
        """
        build_conan_cmd = self.get_finalized_command("build_conan")
        possible_locations = [
            os.path.abspath(self.build_temp),
            os.path.abspath(os.path.join(self.build_temp, "generators")),
            os.path.abspath(build_conan_cmd.build_temp),
            os.path.abspath(os.path.join(build_conan_cmd.build_temp, "build")),
            os.path.abspath(os.path.join(build_conan_cmd.build_temp, "build", "generators")),
            os.path.abspath(os.path.join(build_conan_cmd.build_temp, "build", "Release", "generators")),
        ]

        for location in possible_locations:
            cmake_presets_json = os.path.join(location, "CMakePresets.json")
            if os.path.exists(cmake_presets_json):
                return cmake_presets_json
        raise FileNotFoundError(f"CMakePresets.json not found, searched in: {*possible_locations,}")

    def run(self):
        build_conan_cmd = self.get_finalized_command("build_conan")
        try:
            locate_conan_build_info_json(build_conan_cmd.build_temp)
        except FileNotFoundError:
            # if conan was not run there will be no conan_build_info.json, so we run it now
            build_conan_cmd.run()
        super().run()


    def build_extension(self, ext: Pybind11Extension) -> None:
        if ext.name == MEDIACONCH_EXTENSION:
            configure_pymediaconch(self, ext)
        super().build_extension(ext)

setup(
    ext_modules = [
        Pybind11Extension(
            name=MEDIACONCH_EXTENSION,
            sources=["src/uiucprescon/pymediaconch/pymediaconch.cpp"],
            libraries=['mediaconch'],
            cxx_std=11,
        ),
    ],
    cmdclass={
        "build_ext": BuildExtension,
    }
)
