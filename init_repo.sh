#!/bin/bash

mkdir -p yocto
cd yocto

REPO=$(git config --get remote.origin.url)

if [ ! -z "${REPO}" ] ; then
    repo init -u "${REPO}"
    repo sync
fi
