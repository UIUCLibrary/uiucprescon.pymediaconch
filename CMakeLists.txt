cmake_minimum_required(VERSION 3.5)
project(uiucprescon_PyMediaConch)
set(CMAKE_CXX_STANDARD 11)
include(FetchContent)
cmake_policy(SET CMP0135 NEW)
option(${PROJECT_NAME}_build_python_extension "Build Python extension" OFF)
option(MEDIACONCH_WITH_SQLITE      "Enable SQLite DB"          OFF)
option(MEDIACONCH_WITH_JANSSON     "Enable Jansson Library"    OFF)
option(MEDIACONCH_WITH_LIBEVENT    "Enable Libevent"           OFF)

find_package(ZLIB REQUIRED)
find_package(ZenLib REQUIRED)
find_package(libxml2 REQUIRED)
find_package(LibXslt REQUIRED)
find_package(MediaInfoLib REQUIRED)
find_package(jansson QUIET)
find_package(Libevent QUIET)

FetchContent_Declare(
    MediaConchSource
        GIT_REPOSITORY https://github.com/MediaArea/MediaConch_SourceCode.git
        GIT_TAG        61d878d177d8a19cf99c523d5019a7197c905040
#    URL https://github.com/MediaArea/MediaConch_SourceCode/archive/refs/tags/v25.04.tar.gz
#    URL_HASH SHA256=08cdc983e252292497808de75797fcea997cf9e2ecc2fbcfb3ec9b7f4ebfdfbf
)

FetchContent_Declare(Pybind11
    URL https://github.com/pybind/pybind11/archive/refs/tags/v2.11.1.tar.gz
    URL_HASH SHA256=d475978da0cdc2d43b73f30910786759d593a9d8ee05b1b6846d1eb16c6d2e0c
#todo: set this back to v3.0.0 when uiucprescon.build can use other versions of Pybind11
#    URL https://github.com/pybind/pybind11/archive/refs/tags/v3.0.0.tar.gz
#    URL_HASH SHA256=453b1a3e2b266c3ae9da872411cadb6d693ac18063bd73226d96cfb7015a200c
)


FetchContent_MakeAvailable(MediaConchSource)

if(${PROJECT_NAME}_build_python_extension)

    FetchContent_MakeAvailable(Pybind11)
    add_subdirectory(${pybind11_SOURCE_DIR})
    find_package(Python COMPONENTS Interpreter Development REQUIRED)
    pybind11_add_module(pymediametadata src/uiucprescon/pymediaconch/pymediaconch.cpp)
    target_link_libraries(pymediametadata PRIVATE MediaConchLib)

endif ()

