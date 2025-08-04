from conan import ConanFile
from conan.tools.cmake import cmake_layout
# from conan.tools.cmake import CMakeToolchain, CMake, cmake_layout, CMakeDeps

class MediaConch(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires("zlib/1.3.1")
        self.requires("libxslt/1.1.43")
        self.requires("libxml2/2.13.8")
        self.requires("libzen/0.4.38")
        self.requires("libmediainfo/22.03")

    def layout(self):
        cmake_layout(self)