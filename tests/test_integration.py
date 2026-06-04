import json
import os
import shutil
import subprocess
import pytest
import sample_media_files
from uiucprescon.pymediaconch import mediaconch

PYMEDIACONCH_SAMPLE_FILES_ENV_VARIABLE = "PYMEDIACONCH_SAMPLE_FILES"

@pytest.fixture(scope="session")
def sample_files(tmp_path_factory):
    if not any(condition for condition in [
        os.getenv(PYMEDIACONCH_SAMPLE_FILES_ENV_VARIABLE),
        shutil.which('ffmpeg')
    ]):
        pytest.skip(
            f"neither environment variable "
            f"{PYMEDIACONCH_SAMPLE_FILES_ENV_VARIABLE} nor ffmpeg was found, "
            f"skipping integration test"
        )
    if sample_file_path := os.getenv(PYMEDIACONCH_SAMPLE_FILES_ENV_VARIABLE):
        return sample_media_files.get_sample_files(sample_file_path)

    return sample_media_files.create_sample_files(tmp_path_factory.mktemp('samples'))

def test_integration(sample_files, tmpdir, monkeypatch):
    test_path = tmpdir.mkdir('testing_area')
    bar_and_tone = test_path / 'bars.mp4'
    shutil.copy(str(sample_files['bars_and_tone_file']), str(bar_and_tone))
    monkeypatch.chdir(test_path)
    print(f"getcwd = {os.getcwd()}")

    mc = mediaconch.MediaConch()
    mc.set_format(mediaconch.MediaConch_format_t.MediaConch_format_Json)
    file_id = mc.add_file(str(bar_and_tone))
    report = json.loads(mc.get_report(file_id))
    assert report['MediaConch']['media'][0]['ref'] == str(bar_and_tone)

