from conan import ConanFile
from conan.tools.cmake import cmake_layout

class MediaConch(ConanFile):
    settings = "os", "compiler", "build_type", "arch"
    generators = "CMakeDeps", "CMakeToolchain"

    def requirements(self):
        self.requires("zlib/1.3.1")
        self.requires("libxslt/1.1.43")
        self.requires("libxml2/2.13.8")
        self.requires("libmediainfo/26.01")

    def layout(self):
        cmake_layout(self)