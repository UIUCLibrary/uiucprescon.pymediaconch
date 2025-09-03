//
// Created by Borchers, Henry Samuel on 7/30/25.
//
#include <pybind11/pybind11.h>
#include <MediaConch/MediaConchDLL.h>

namespace py = pybind11;
// NOLINTNEXTLINE(readability-identifier-length, modernize-use-trailing-return-type)
PYBIND11_MODULE(mediaconch, mod, py::mod_gil_not_used()) {
    mod.doc() = "Python bindings for libmediaconch Library";

    // // Bindings for the MediaConchLib class
    py::class_<MediaConch::MediaConch>(mod, "MediaConch")
        .def(py::init<>(), "Initialize the MediaConch library")
        .def("add_file",         &MediaConch::MediaConch::add_file,           py::arg("filename"),     "Add a file to the MediaConch library")
        .def("get_report",       &MediaConch::MediaConch::get_report,         py::arg("file_id"),      "Get report for a file")
        .def("add_policy",       &MediaConch::MediaConch::add_policy,         py::arg("filename"),     "Add a policy file")
        .def("set_format",       &MediaConch::MediaConch::set_format,         py::arg("format"),       "Set output format")
        .def("get_last_error",   &MediaConch::MediaConch::get_last_error,                              "Get last error message");
        ;
    py::enum_<MediaConch_format_t>(mod, "MediaConch_format_t")
        .value("MediaConch_format_Text",     MediaConch_format_Text)
        .value("MediaConch_format_Xml",      MediaConch_format_Xml)
        .value("MediaConch_format_MaXml",    MediaConch_format_MaXml)
        .value("MediaConch_format_JsTree",   MediaConch_format_JsTree)
        .value("MediaConch_format_Html",     MediaConch_format_Html)
        .value("MediaConch_format_OrigXml",  MediaConch_format_OrigXml)
        .value("MediaConch_format_Simple",   MediaConch_format_Simple)
        .value("MediaConch_format_CSV",      MediaConch_format_CSV)
        .value("MediaConch_format_Json",     MediaConch_format_Json)
        .value("MediaConch_format_Max",      MediaConch_format_Max)
    ;
}