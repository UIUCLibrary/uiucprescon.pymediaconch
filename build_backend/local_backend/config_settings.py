import json
import os


def get_config_settings():
    config_json_file = os.path.join("build", "config_settings.json")
    if not os.path.exists(config_json_file):
        return {}
    with open(config_json_file, "r") as f:
        return json.load(f)