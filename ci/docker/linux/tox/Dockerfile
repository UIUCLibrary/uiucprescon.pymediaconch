ARG CONAN_USER_HOME=/conan
ARG CONAN_HOME=${CONAN_USER_HOME}/.conan2
ARG PIP_CACHE_DIR=/.cache/pip
ARG UV_CACHE_DIR=/.cache/uv
ARG UV_INDEX_URL

FROM ubuntu:24.04 AS base
COPY ci/docker/linux/tox/apt-packages.txt /tmp/apt-packages.txt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN apt-get update && \
    apt-get install -y software-properties-common gpg-agent --no-install-recommends && \
    add-apt-repository ppa:deadsnakes/ppa && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata && \
    apt-get update && \
     < /tmp/apt-packages.txt xargs apt-get install -y && \
    apt-get clean && \
    rm -rf /var/lib/apt/lists/*


FROM base AS conan_builder
ARG UV_INDEX_URL
COPY requirements-dev.txt /tmp/requirements/requirements-dev.txt
ARG CONAN_HOME
COPY ci/docker/shared/conan/remotes.json  ${CONAN_HOME}/remotes.json
COPY ci/docker/linux/tox/conan/profile.ini ${CONAN_HOME}/profiles/default
COPY conanfile.py /tmp/conanfile.py
ENV UV_CONSTRAINT=/tmp/requirements/requirements-dev.txt
RUN python3 -m venv venv --upgrade-deps && \
    ./venv/bin/pip install --disable-pip-version-check uv && \
    ./venv/bin/uvx --with cmake conan profile detect --exist-ok &&  \
    ./venv/bin/uvx --with cmake conan install /tmp -pr:b=default --build missing && \
    ./venv/bin/uvx --with cmake conan cache clean "*" -b --source --build --temp && \
    ./venv/bin/uv cache clean && \
    rm -rf venv

# ==============================================================================

FROM base
ARG CONAN_USER_HOME
ARG CONAN_HOME

COPY --from=conan_builder ${CONAN_HOME}/ ${CONAN_HOME}/
RUN chmod -R 777 ${CONAN_HOME}

ARG PIP_CACHE_DIR
ARG UV_CACHE_DIR
RUN mkdir -p ${PIP_CACHE_DIR} && \
    chmod -R 777 ${PIP_CACHE_DIR} && \
    mkdir -p ${UV_CACHE_DIR} && \
    chmod -R 777 ${UV_CACHE_DIR}

ENV PIP_CACHE_DIR=${PIP_CACHE_DIR} \
    UV_CACHE_DIR=${UV_CACHE_DIR} \
    UV_INDEX_STRATEGY=unsafe-best-match \
    CONAN_USER_HOME=${CONAN_USER_HOME}\
    CONAN_HOME=${CONAN_HOME}
