import abc
import json
import logging
import os
import pathlib
import copy
import sys
import sysconfig
from typing import List, Type, Callable
from . import utils

from conan.api.conan_api import ConanAPI
from conan.cli.cli import Cli

logger = logging.getLogger(__name__)
logger.setLevel(logging.DEBUG)


class AbsConanCommandBuilder(abc.ABC):
    def __init__(self) -> None:
        # self.extension_command = extension_command
        self.conanfile = None

    @abc.abstractmethod
    def get_install_command(self, build_path: str) -> List[str]:
        """Get the command to run conan install."""


class BaseConanCommandBuilder(AbsConanCommandBuilder):
    def get_install_command(self, build_path: str) -> List[str]:
        search_path = os.path.dirname(sys.executable)
        conan_command = [
            "install",
            self.conanfile or ".",
            "--build=missing",
            "-of",
            build_path,
        ]
        return conan_command


class MacOSConanCommandBuilder(BaseConanCommandBuilder):
    @staticmethod
    def determine_mac_archs():
        key = {"arm64": "armv8", "x86_64": "x86_64"}
        cflags = sysconfig.get_config_vars().get("CONFIGURE_CFLAGS")
        arches = []
        for arch in key.keys():
            if arch in cflags:
                arches.append(key[arch])

        if len(arches) == 0:
            print(f"Unable to determine architecture. CONFIGURE_CFLAGS = {cflags}")
            raise ValueError("No valid architecture found")
        return arches

    def get_install_command(self, build_path: str) -> List[str]:
        command = super().get_install_command(build_path)
        command.append(f"-s=os.version={utils.get_mac_deploy_target()}")
        try:
            archs = self.determine_mac_archs()
            archs.sort()
            command.append(f"-s=arch={'|'.join(archs)}")
        except ValueError:
            print("No valid architecture found. Using default.")

        return command


def default_conan_command_builder() -> Type[AbsConanCommandBuilder]:
    if sys.platform == "darwin":
        return MacOSConanCommandBuilder
    return BaseConanCommandBuilder


class ConanCommandBuilder:
    def __init__(self, builder: AbsConanCommandBuilder) -> None:
        self.builder = builder

    @property
    def conanfile(self) -> str:
        return self.builder.conanfile

    @conanfile.setter
    def conanfile(self, value: str) -> None:
        self.builder.conanfile = value

    def get_install_command(self, build_path: str) -> List[str]:
        return self.builder.get_install_command(build_path)


def update_generated_conan_preset_name(
    cmake_user_preset_file,
    include_path_to_preset,
    conan_config_preset_name,
    conan_build_preset_name,
    conan_test_preset_name,
):
    with open(cmake_user_preset_file, "r", encoding="utf-8") as f:
        top_level_cmake_user_preset_data = json.loads(f.read())

    for include in top_level_cmake_user_preset_data["include"]:
        if (
            pathlib.Path(include)
            .resolve()
            .is_relative_to(pathlib.Path(include).resolve())
        ):
            cmake_preset_path = include
            break
    else:
        raise FileNotFoundError(f"Missing {include_path_to_preset}")

    print(f"Found preset path {cmake_preset_path}")
    with open(cmake_preset_path, "r", encoding="utf-8") as f:
        cmake_preset_data = json.loads(f.read())
    original_data = copy.deepcopy(cmake_preset_data)

    if len(cmake_preset_data["configurePresets"]) > 1:
        raise ValueError("Too many configurePresets to update")
    if len(cmake_preset_data["buildPresets"]) > 1:
        raise ValueError("Too many buildPresets to update")
    if len(cmake_preset_data["testPresets"]) > 1:
        raise ValueError("Too many testPresets to update")

    config_preset = cmake_preset_data["configurePresets"][0]
    config_preset["name"] = conan_config_preset_name

    build_preset = cmake_preset_data["buildPresets"][0]
    build_preset["name"] = conan_build_preset_name
    build_preset["configurePreset"] = conan_config_preset_name

    test_preset = cmake_preset_data["testPresets"][0]
    test_preset["name"] = conan_test_preset_name
    test_preset["configurePreset"] = conan_config_preset_name
    if original_data != cmake_preset_data:
        print(f"Updating file {cmake_preset_path}")
        with open(cmake_preset_path, "w", encoding="utf-8") as f:
            json.dump(cmake_preset_data, f, indent=4)


def conan_install(
    conanfile, build_path, spawn_cmd: Callable[[List[str]], None]
) -> None:
    command_builder = ConanCommandBuilder(builder=default_conan_command_builder()())
    command_builder.conanfile = conanfile
    conan_api = ConanAPI()
    cli = Cli(conan_api)
    cli.add_commands()
    conan_api.command.run(command_builder.get_install_command(build_path))
