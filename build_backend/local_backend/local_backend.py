from __future__ import annotations
from typing import Optional, Dict, Union, List

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


def build_wheel(
    wheel_directory: str,
    config_settings: Optional[Dict[str, Union[str, List[str], None]]] = None,
    metadata_directory: Optional[str] = None,
) -> str:
    return setuptools.build_meta.build_wheel(
        wheel_directory, config_settings, metadata_directory
    )
def get_requires_for_build_wheel(config_settings):
    return ["cmake", "nanobind", "conan>2.0",  "setuptools"]

def get_requires_for_build_sdist(config_settings):
    return ['setuptools']