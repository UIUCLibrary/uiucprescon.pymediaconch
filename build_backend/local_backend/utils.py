import os
import sysconfig

__all__ = ["get_mac_deploy_target"]


def get_mac_deploy_target():
    if deploy_target := os.getenv("MACOSX_DEPLOYMENT_TARGET"):
        return deploy_target

    python_built_with = sysconfig.get_config_vars().get("MACOSX_DEPLOYMENT_TARGET")
    # nanobind needs at least macOS 10.13
    if (
        python_built_with.split(".")[0] == "10"
        and int(python_built_with.split(".")[1]) < 13
    ):
        return "10.13"
    if len(python_built_with.split(".")) == 1:
        return f"{python_built_with}.0"
    return python_built_with
