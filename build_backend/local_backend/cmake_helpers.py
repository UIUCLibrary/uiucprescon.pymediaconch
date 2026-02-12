from __future__ import annotations

import abc
import logging
import os
import pathlib
import shutil
import sys
import sysconfig
from typing import Type, List, Optional

from . import utils

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


def locate_cmake_cache(build_path):
    for root, dirs, files in os.walk(build_path):
        for file in files:
            if "CMakeCache.txt" != file:
                continue
            cmake_cache_path = os.path.join(root, file)
            return cmake_cache_path
    raise FileNotFoundError("CMakeCache.txt not found in build directory")


class AbsCMakeCommandBuilder(abc.ABC):
    def __init__(self):
        super().__init__()
        self.cmake_config_preset = None
        self.cmake_build_preset = None
        self.announce = lambda message, level=logging.INFO: logger.log(
            level=level, msg=message
        )

    @abc.abstractmethod
    def build_command(self) -> List[str]:
        """Get the cmake build command."""

    @abc.abstractmethod
    def configure_command(self, build_path, output_path):
        """Get the cmake configure command."""


class CMakeCommandBuilder:
    def __init__(self, builder: AbsCMakeCommandBuilder) -> None:
        self.builder = builder

    @property
    def cmake_config_preset(self) -> Optional[str]:
        return self.builder.cmake_config_preset

    @cmake_config_preset.setter
    def cmake_config_preset(self, value: str) -> None:
        self.builder.cmake_config_preset = value

    @property
    def cmake_build_preset(self) -> Optional[str]:
        return self.builder.cmake_build_preset

    @cmake_build_preset.setter
    def cmake_build_preset(self, value: str) -> None:
        self.builder.cmake_build_preset = value

    def configure_command(self, build_path, output_path) -> List[str]:
        return self.builder.configure_command(build_path, output_path)

    def build_command(self) -> List[str]:
        return self.builder.build_command()

def locate_cmake():
    import cmake
    cmake_exec = shutil.which("cmake", path=cmake.CMAKE_BIN_DIR)
    if not cmake_exec:
        raise FileNotFoundError("cmake executable not found")
    return cmake_exec


class BaseCMakeCommandBuilder(AbsCMakeCommandBuilder):
    def build_command(self) -> List[str]:
        cmake_exec = locate_cmake()
        build_command = [
            cmake_exec,
            "--build",
        ]
        if cmake_preset := self.cmake_build_preset:
            build_command.append(f"--preset={cmake_preset}")
        else:
            self.announce(
                "No CMake preset specified. This may lead to unexpected build results.",
                level=logging.WARNING,
            )

        build_command += ["--target", "install"]
        return build_command

    def configure_command(self, build_path, output_path):
        import nanobind
        cmake_exec = locate_cmake()
        command = [
            cmake_exec,
        ]
        if conan_preset := self.cmake_config_preset:
            command.append(f"--preset={conan_preset}")
        else:
            self.announce(
                "No CMake preset specified. This may lead to unexpected build results.",
                level=logging.WARNING,
            )
        python_root = sysconfig.get_paths().get("data")
        if not python_root:
            raise FileNotFoundError("unable to locate python installation prefix")
        command += [
            "-Duiucprescon_PyMediaConch_build_python_extension=ON",
            f"-DPython_ROOT_DIR:PATH={python_root}",
            f"-DPython_EXECUTABLE:FILEPATH={sys.executable}",
            f"-DPython_INCLUDE_DIR:FILEPATH={sysconfig.get_paths()['include']}",
            "-DPython_ARTIFACTS_INTERACTIVE=true",
            "-DCMAKE_POSITION_INDEPENDENT_CODE=true",
            f"-Dnanobind_DIR:PATH={nanobind.cmake_dir()}",
            f"-DPython_FIND_STRATEGY=LOCATION",
            f"-DCMAKE_INSTALL_PREFIX:PATH={os.path.abspath(output_path)}",
        ]
        return command


class MacOSCMakeCommandBuilder(BaseCMakeCommandBuilder):
    conan_preset_name = "conan-release"

    @staticmethod
    def determine_arches():
        cflags = sysconfig.get_config_vars().get("CONFIGURE_CFLAGS")
        arches = []
        for arch in ["arm64", "x86_64"]:
            if arch in cflags:
                arches.append(arch)
        if len(arch) == 0:
            print(
                f'Unable to determine architecture from CONFIGURE_CFLAGS value. "{cflags}"'
            )
            raise ValueError("No valid architecture found")
        return arches

    def configure_command(self, build_path, output_path):
        command = super().configure_command(build_path, output_path)
        command.append(f"-DCMAKE_OSX_DEPLOYMENT_TARGET={utils.get_mac_deploy_target()}")

        try:
            command.append(
                f"-DCMAKE_OSX_ARCHITECTURES={';'.join(self.determine_arches())}"
            )
        except ValueError:
            print("No valid architecture found. Using default.")
        return command


def default_cmake_command_builder() -> Type[AbsCMakeCommandBuilder]:
    if sys.platform == "darwin":
        return MacOSCMakeCommandBuilder
    return BaseCMakeCommandBuilder


def build_cmake_extension(
    build_path,
    output_path,
    spawn_command,
    cmake_config_preset=None,
    cmake_build_preset=None,
    announce=lambda message, level=logging.INFO: logger.log(level=level, msg=message),
) -> None:
    cmake_command_builder = CMakeCommandBuilder(default_cmake_command_builder()())
    cmake_command_builder.cmake_config_preset = cmake_config_preset
    cmake_command_builder.cmake_build_preset = cmake_build_preset
    announce(f"Configuring build using CMake", level=logging.INFO)
    spawn_command(cmake_command_builder.configure_command(build_path, output_path))
    announce(f"Configuring build using CMake - DONE", level=logging.DEBUG)
    cmake_cache = locate_cmake_cache(build_path)
    errors = []
    with open(cmake_cache, "r") as f:
        for line in f:
            if line.strip().startswith("Python_EXECUTABLE"):
                cmake_path_exec = line.strip().split("=")[1]
                expected_python_exec = sys.executable
                if (
                    pathlib.Path(expected_python_exec).parent
                    != pathlib.Path(cmake_path_exec).parent
                ):
                    errors.append(
                        f"CMake found python executable {cmake_path_exec} which does not match the python executable used to run setup.py {expected_python_exec}"
                    )
    if errors:
        raise ValueError("\n".join(errors))

    announce(f"Building extension using CMake", level=logging.INFO)
    spawn_command(cmake_command_builder.build_command())
    announce(f"Building extension using CMake - DONE", level=logging.DEBUG)
