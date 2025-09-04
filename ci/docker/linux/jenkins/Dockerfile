ARG CONAN_CENTER_PROXY_V2_URL=https://center2.conan.io
# If you want to use a diffrent remote for Conan, such as a proxy. Set the CONAN_CENTER_PROXY_V2_URL
# Not this is only for building the image. The actual conan center proxy URL is set in the remotes.json file.

ARG PIP_CACHE_DIR=/.cache/pip
# PIP Cache directory. Change this only if you need to override the default location.

ARG UV_CACHE_DIR=/.cache/uv
# UV Cache directory. Change this only if you need to override the default location.

ARG CONAN_USER_HOME=/conan
ARG CONAN_HOME=${CONAN_USER_HOME}/.conan2

FROM ubuntu:24.04 AS base
RUN --mount=type=cache,target=/var/cache/apt,sharing=locked \
    --mount=type=cache,target=/var/lib/apt,sharing=locked \
    --mount=type=bind,source=ci/docker/linux/jenkins/apt-packages.txt,target=/tmp/apt-packages.txt \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update -y &&  \
    < /tmp/apt-packages.txt xargs apt-get install -y && \
    apt-get install -y --no-install-recommends  && \
    rm -rf /var/lib/apt/lists/*

# =============================================================================
FROM base AS conan_builder
RUN --mount=type=cache,target=/var/cache/apt \
    rm -f /etc/apt/apt.conf.d/docker-clean && \
    apt-get update && \
    apt-get install -y --no-install-recommends jq && \
    rm -rf /var/lib/apt/lists/*
ARG CONAN_HOME
COPY ci/docker/shared/conan/remotes.json  ${CONAN_HOME}/remotes.json
ARG PIP_INDEX_URL
ARG CONAN_CENTER_PROXY_V2_URL
ARG UV_CACHE_DIR
ENV UV_CONSTRAINT=/tmp/requirements-dev.txt
ARG PIP_CACHE_DIR
ARG CONAN_DOWNLOAD_CACHE=/tmp/conan_download_cache
RUN --mount=type=cache,target=${PIP_CACHE_DIR} \
    --mount=type=cache,target=${UV_CACHE_DIR} \
    --mount=type=cache,target=${CONAN_DOWNLOAD_CACHE} \
    --mount=type=bind,source=uv.lock,target=/tmp/project/uv.lock \
    --mount=type=bind,source=pyproject.toml,target=/tmp/project/pyproject.toml \
    --mount=type=bind,source=conanfile.py,target=/tmp/conanfile.py \
    python3 -m venv venv && \
    ./venv/bin/pip --disable-pip-version-check install uv && \
    ./venv/bin/uv export --frozen --only-dev --no-hashes --directory /tmp/project/ > ${UV_CONSTRAINT} && \
    ./venv/bin/uvx --with cmake conan profile detect --exist-ok &&  \
    cp ${CONAN_HOME}/global.conf /tmp/global.conf.original && \
    echo "core.sources:download_cache = $CONAN_DOWNLOAD_CACHE" >> ${CONAN_HOME}/global.conf && \
    if [ "$(jq -r '.remotes[0].url' ${CONAN_HOME}/remotes.json )" != "${CONAN_CENTER_PROXY_V2_URL}" ]; then \
        echo "Setting the conan center url for building cache: ${CONAN_CENTER_PROXY_V2_URL}" && \
        cp ${CONAN_HOME}/remotes.json /tmp/remotes.json && \
        ./venv/bin/uvx --with cmake conan remote update conan-center --url ${CONAN_CENTER_PROXY_V2_URL}; \
    fi && \
    ./venv/bin/uvx --with cmake conan install /tmp -pr:b=default --build missing -pr:b=default && \
    ./venv/bin/uvx --with cmake conan cache clean "*" -b --source --build --temp && \
    rm -rf venv && \
    if [ "$(jq -r '.remotes[0].url' ${CONAN_HOME}/remotes.json )" != "${CONAN_CENTER_PROXY_V2_URL}" ]; then \
      mv -f /tmp/remotes.json ${CONAN_HOME}/remotes.json; \
    fi && \
    mv -f /tmp/global.conf.original ${CONAN_HOME}/global.conf

#==============================================================================
FROM base
ARG CONAN_USER_HOME
ARG CONAN_HOME
COPY --from=conan_builder ${CONAN_HOME}/ ${CONAN_HOME}/
ENV CONAN_USER_HOME=${CONAN_USER_HOME} \
    CONAN_HOME=${CONAN_HOME}
RUN  chmod -R 777 ${CONAN_HOME}
