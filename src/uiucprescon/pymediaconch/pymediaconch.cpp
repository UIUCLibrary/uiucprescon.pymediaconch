//
// Created by Borchers, Henry Samuel on 7/30/25.
//
#include <nanobind/nanobind.h>
#include <MediaConchDLL.h>

namespace nb = nanobind;
// NOLINTNEXTLINE(readability-identifier-length, modernize-use-trailing-return-type)
NB_MODULE(mediaconch, mod) {
    mod.doc() = "Python bindings for libmediaconch Library";

    // // Bindings for the MediaConchLib class
    nb::class_<MediaConch::MediaConch>(mod, "MediaConch")
        .def(nb::init<>(), "Initialize the MediaConch library")
        .def("add_file",         &MediaConch::MediaConch::add_file,           nb::arg("filename"),     "Add a file to the MediaConch library")
        .def("get_report",       &MediaConch::MediaConch::get_report,         nb::arg("file_id"),      "Get report for a file")
        .def("add_policy",       &MediaConch::MediaConch::add_policy,         nb::arg("filename"),     "Add a policy file")
        .def("set_format",       &MediaConch::MediaConch::set_format,         nb::arg("format"),       "Set output format")
        .def("get_last_error",   &MediaConch::MediaConch::get_last_error,                              "Get last error message");
        ;
    nb::enum_<MediaConch_format_t>(mod, "MediaConch_format_t")
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