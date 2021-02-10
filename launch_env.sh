#!/bin/bash

#ensure repo is there

WORKING_DIR="$(pwd)"

SUPPORTED_DISTRO_FILE=./yocto/meta-poky/conf/distro/poky.conf

if [ ! -f  "./yocto" ] ; then
    REPO_PATH="$(pwd)/repo"
    curl https://storage.googleapis.com/git-repo-downloads/repo > ${REPO_PATH}
    chmod a+rx "${REPO_PATH}"
    mkdir -p yocto
    cd yocto
    REPO=$(git config --get remote.origin.url)
    if [ ! -z "${REPO}" ] ; then
        repo init -u "${REPO}"
        repo sync
    fi
    rm -f "${REPO_PATH}"
    cd ${WORKING_DIR}
fi

if [ ! -f  "${SUPPORTED_DISTRO_FILE}" ] ; then
    echo "Failed to read ${SUPPORTED_DISTRO_FILE}"
    exit 1
fi

PREFERED_DISTRO="fedora"
PREFERED_DISTRO_UPDATE_METHOD="dnf update -y"
PREFERED_DISTRO_INSTALL_METHOD="dnf install -y"
PREFERED_DISTRO_CLEANUP_INSTALL_METHOD="dnf clean all"

YOCTO_INSTALL_PATH="$(cd yocto && pwd)"

INSTALL_LIST="bash cpio hostname rpcgen gawk make wget tar xz bzip2 gzip python unzip perl patch \
     diffutils diffstat git cpp gcc gcc-c++ glibc-locale-source glibc-langpack-en glibc-devel texinfo chrpath \
     ccache perl-Data-Dumper perl-Text-ParseWords perl-Thread-Queue socat \
     findutils which SDL-devel xterm"

LATEST_DISTRO_VERSION="$(cat "${SUPPORTED_DISTRO_FILE}" | grep -zo SANITY_TESTED_DISTROS[^\"]*\"[^\"]*\" | tr -d '\000' | sed -nr 's/.*fedora-([0-9][0-9]).*/\1/p' | sort | tail -1)"

if [ -z "${LATEST_DISTRO_VERSION}" ] ; then
    echo "Failed to find latest supported distro"
    exit 1
fi

DOCKER_TAG="yocto-builder:${PREFERED_DISTRO}-${LATEST_DISTRO_VERSION}"

docker build -t "${DOCKER_TAG}" - <<EOT
FROM ${PREFERED_DISTRO}:${LATEST_DISTRO_VERSION}
RUN ${PREFERED_DISTRO_UPDATE_METHOD}
RUN ${PREFERED_DISTRO_INSTALL_METHOD} ${INSTALL_LIST}
RUN ${PREFERED_DISTRO_CLEANUP_INSTALL_METHOD}
RUN rm /bin/sh && ln -s bash /bin/sh
RUN groupadd -g 1000 build && useradd -u 1000 -g 1000 -ms /bin/bash build && usermod -a -G wheel build && usermod -a -G users build
RUN curl -o /usr/local/bin/repo https://storage.googleapis.com/git-repo-downloads/repo && chmod a+x /usr/local/bin/repo
RUN localedef -v -c -i en_US -f UTF-8 en_US.UTF-8 || true
EOT

if [ $? == 0 ] ; then
    docker run --rm -it -v `pwd`/yocto:`pwd`/yocto -w `pwd`/yocto --rm --name yocto-env --user=build "${DOCKER_TAG}"
fi
