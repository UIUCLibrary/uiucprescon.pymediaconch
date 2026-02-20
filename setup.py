from setuptools import setup
try:
    from local_backend import setuptools_targets
except ModuleNotFoundError:
    # This is a hack so that setup.py can be run from the root directory.
    import sys
    sys.path.insert(0, "build_backend")
    from local_backend import setuptools_targets


setup(
    ext_modules=[
        setuptools_targets.NanobindWithConanfileExtension(
            name="uiucprescon.pymediaconch.mediaconch",
            sources=["src/uiucprescon/pymediaconch/pymediaconch.cpp"],
            libraries=['mediaconch'],
            cxx_std=11,
            conanfile="conanfile.py",
            py_limited_api=True
        ),
    ],
    cmdclass={
        "build_ext": setuptools_targets.BuildNanoBindExtension,
    },
)
