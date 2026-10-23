#!/bin/sh
# RootHide build entry. Usage: sh build.sh roothide
set -e

variant="${1:-roothide}"
if [ "$variant" != "roothide" ]; then
    echo "Only the 'roothide' variant is supported by this project." >&2
    exit 2
fi

if [ -z "${THEOS:-}" ]; then
    echo "THEOS is not set. Point it at a roothide/theos checkout." >&2
    exit 1
fi

export THEOS_PACKAGE_SCHEME=roothide
make clean || true
make messages=yes
