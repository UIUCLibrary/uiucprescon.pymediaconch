import importlib
def test_import_package():
    assert importlib.import_module('uiucprescon.pymediaconch').__name__ == 'uiucprescon.pymediaconch'

def test_import_mediaconch():
    assert importlib.import_module('uiucprescon.pymediaconch.mediaconch').__name__ == 'uiucprescon.pymediaconch.mediaconch'
