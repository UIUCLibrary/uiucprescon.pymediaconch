from __future__ import annotations

import os
from typing import Optional, Dict, Union, List
import json

import setuptools.build_meta

from setuptools.build_meta import (
    build_sdist, build_editable, build_sdist, prepare_metadata_for_build_wheel,
    prepare_metadata_for_build_editable
)

__all__ = [
    "build_wheel", "build_sdist", "build_editable",
    "get_requires_for_build_sdist", "get_requires_for_build_wheel",
    "prepare_metadata_for_build_wheel", "prepare_metadata_for_build_editable"
]

BUILD_METADATA_FILE = "config_settings.json"

def write_build_metadata_file(path, metadata_dict):
    with open(os.path.join(path, BUILD_METADATA_FILE), "w") as f:
        json.dump(metadata_dict, f)


def build_wheel(
    wheel_directory: str,
    config_settings: Optional[Dict[str, Union[str, List[str], None]]] = None,
    metadata_directory: Optional[str] = None,
) -> str:
    build_metadata_file = os.path.join(os.getcwd(), "build", BUILD_METADATA_FILE)
    if os.path.exists(build_metadata_file):
        os.remove(build_metadata_file)
    if config_settings:
        build_path = os.path.join(os.getcwd(), "build")
        if not os.path.exists(build_path):
            os.makedirs(build_path)
        write_build_metadata_file(build_path, config_settings)

    return setuptools.build_meta.build_wheel(
        wheel_directory, config_settings, metadata_directory
    )
def get_requires_for_build_wheel(config_settings):
    return ["cmake", "nanobind", "conan>2.0",  "setuptools"]

def get_requires_for_build_sdist(config_settings):
    return ['setuptools']