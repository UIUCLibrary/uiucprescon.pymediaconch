ARG CONAN_USER_HOME=/conan
ARG CONAN_HOME=${CONAN_USER_HOME}/.conan2
ARG PIP_CACHE_DIR=/.cache/pip
ARG UV_CACHE_DIR=/.cache/uv
ARG UV_INDEX_URL

ARG CONAN_CENTER_PROXY_V2_URL=https://center2.conan.io
# If you want to use a diffrent remote for Conan, such as a proxy. Set the CONAN_CENTER_PROXY_V2_URL
# Not this is only for building the image. The actual conan center proxy URL is set in the remotes.json file.


FROM ubuntu:24.04 AS base
COPY ci/docker/linux/tox/apt-packages.txt /tmp/apt-packages.txt
SHELL ["/bin/bash", "-o", "pipefail", "-c"]
RUN rm -f /etc/apt/apt.conf.d/docker-clean
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -y software-properties-common gpg-agent --no-install-recommends && \
    add-apt-repository ppa:deadsnakes/ppa && \
    DEBIAN_FRONTEND=noninteractive TZ=Etc/UTC apt-get -y install tzdata && \
    apt-get update && \
     < /tmp/apt-packages.txt xargs apt-get install -y && \
    rm -rf /var/lib/apt/lists/*


FROM base AS conan_builder
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    apt-get update && \
    case "$(uname -m)" in \
          aarch64) \
            apt-get install -y --no-install-recommends m4 libtool meson ninja-build pkgconf autoconf automake build-essential\
          ;;\
          x86_64) \
            apt-get install -y --no-install-recommends ninja-build \
          ;;\
    esac && \
    apt-get install -y --no-install-recommends jq && \
    rm -rf /var/lib/apt/lists/*


ARG UV_INDEX_URL
COPY requirements-dev.txt /tmp/requirements/requirements-dev.txt
ARG CONAN_HOME
ARG PIP_CACHE_DIR
ARG UV_CACHE_DIR
ARG CONAN_CENTER_PROXY_V2_URL
ARG CONAN_DOWNLOAD_CACHE=/tmp/conan_download_cache
COPY ci/docker/shared/conan/remotes.json  ${CONAN_HOME}/remotes.json
COPY ci/docker/linux/tox/conan/profile.ini ${CONAN_HOME}/profiles/default
COPY conanfile.py /tmp/conanfile.py
ENV UV_CONSTRAINT=/tmp/requirements/requirements-dev.txt
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target=${UV_CACHE_DIR} \
    --mount=type=cache,target=${CONAN_DOWNLOAD_CACHE} \
    python3 -m venv venv --upgrade-deps && \
    ./venv/bin/pip install --disable-pip-version-check uv && \
    ./venv/bin/uvx --with cmake conan profile detect --exist-ok &&  \
    cp ${CONAN_HOME}/global.conf /tmp/global.conf.original && \
    echo "core.sources:download_cache = $CONAN_DOWNLOAD_CACHE" >> ${CONAN_HOME}/global.conf && \
    if [ "$(jq -r '.remotes[0].url' ${CONAN_HOME}/remotes.json )" != "${CONAN_CENTER_PROXY_V2_URL}" ]; then \
        echo "Setting the conan center url for building cache: ${CONAN_CENTER_PROXY_V2_URL}" && \
        cp ${CONAN_HOME}/remotes.json /tmp/remotes.json && \
        ./venv/bin/uvx --with cmake conan remote update conan-center --url ${CONAN_CENTER_PROXY_V2_URL}; \
    fi && \
    ./venv/bin/uvx --with cmake --with ninja conan install /tmp/conanfile.py -pr:b=default --build missing -c tools.cmake.cmaketoolchain:generator=Ninja && \
    ./venv/bin/uvx --with cmake conan cache clean "*" -b --source --build --temp && \
    rm -rf venv && \
    mv -f /tmp/global.conf.original ${CONAN_HOME}/global.conf && \
    if [ "$(jq -r '.remotes[0].url' ${CONAN_HOME}/remotes.json )" != "${CONAN_CENTER_PROXY_V2_URL}" ]; then \
        mv -f /tmp/remotes.json ${CONAN_HOME}/remotes.json; \
    fi

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
