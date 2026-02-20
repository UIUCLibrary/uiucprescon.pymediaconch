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
        GIT_TAG        5823658764db3dc7f5d7b82b8f8909cfad43f7d8
        EXCLUDE_FROM_ALL
)


FetchContent_MakeAvailable(MediaConchSource)

if(${PROJECT_NAME}_build_python_extension)
    find_package(Python COMPONENTS Interpreter Development.Module Development.SABIModule REQUIRED)
    # Detect the installed nanobind package and import it into CMake
    if(NOT nanobind_DIR)
        execute_process(
            COMMAND "${Python_EXECUTABLE}" -m nanobind --cmake_dir
            OUTPUT_STRIP_TRAILING_WHITESPACE OUTPUT_VARIABLE nanobind_DIR
        )
    endif()
    find_package(nanobind CONFIG REQUIRED)
    nanobind_add_module(mediaconch STABLE_ABI FREE_THREADED src/uiucprescon/pymediaconch/pymediaconch.cpp)
    target_link_libraries(mediaconch PRIVATE MediaConchLib)
    target_include_directories(mediaconch PRIVATE ${mediaconchsource_SOURCE_DIR}/Source/Lib)
    install(TARGETS mediaconch LIBRARY DESTINATION "uiucprescon/pymediaconch")
endif ()

