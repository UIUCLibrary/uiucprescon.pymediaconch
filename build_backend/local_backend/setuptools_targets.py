import logging
import os
import sys

from setuptools.command.build_ext import Extension as _Extension
from setuptools.command.build_ext import build_ext as _build_ext
from . import cmake_helpers
from . import conan_helpers


class NanobindWithConanfileExtension(_Extension):
    def __init__(self, *args, conanfile=None, **kwargs):
        super().__init__(*args, **kwargs)
        self.conanfile = conanfile


class BuildNanoBindExtension(_build_ext):
    def finalize_options(self) -> None:
        if build_temp := os.getenv("SETUPTOOLS_BUILD_TEMP_DIR"):
            self.build_temp = build_temp
        super().finalize_options()

    def build_extension(self, ext: _build_ext) -> None:
        build_path = os.path.join(self.build_temp, f"{ext.name}_build")
        if not os.path.exists(build_path):
            self.mkpath(build_path)
        self.announce(f"Using build path {build_path}", level=logging.INFO)
        self.announce("Building dependencies with conan", level=logging.INFO)
        conan_helpers.conan_install(
            conanfile=ext.conanfile, build_path=build_path, spawn_cmd=self.spawn
        )
        self.announce("Building dependencies with conan - Done", level=logging.INFO)
        conan_config_preset_name = (
            f"python-{sys.version_info.major}.{sys.version_info.minor}-config"
        )
        conan_build_preset_name = (
            f"python-{sys.version_info.major}.{sys.version_info.minor}-build"
        )
        conan_test_preset_name = (
            f"python-{sys.version_info.major}.{sys.version_info.minor}-test"
        )
        if os.path.exists("CMakeUserPresets.json"):
            self.announce(
                f"Updated CMake preset to avoid name conflicts", level=logging.DEBUG
            )
            conan_helpers.update_generated_conan_preset_name(
                "CMakeUserPresets.json",
                build_path,
                conan_config_preset_name=conan_config_preset_name,
                conan_build_preset_name=conan_build_preset_name,
                conan_test_preset_name=conan_test_preset_name,
            )
            self.announce(
                f"Updated CMake preset names to {conan_config_preset_name}, {conan_build_preset_name}, {conan_test_preset_name}",
                level=logging.DEBUG,
            )
        else:
            self.warn(
                "Unable to update cmake preset name because CMakeUserPresets.json was not found."
            )

        self.announce("Building extension with CMake", level=logging.INFO)

        cmake_helpers.build_cmake_extension(
            build_path,
            self.build_lib,
            spawn_command=self.spawn,
            cmake_build_preset=conan_build_preset_name,
            cmake_config_preset=conan_config_preset_name,
            announce=self.announce,
        )

        if sys.version_info >= (3, 12):
            self.get_finalized_command("bdist_wheel").py_limited_api = "cp312"
        else:
            ext.py_limited_api = False
            self.get_finalized_command("bdist_wheel").py_limited_api = False
