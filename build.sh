#!/bin/sh
# Usage: sh build.sh roothide
set -e
variant="${1:-roothide}"
if [ "$variant" != "roothide" ]; then
    echo "Only the roothide scheme is supported." >&2
    exit 2
fi
if [ -z "${THEOS:-}" ]; then
    echo "THEOS must point to roothide/theos." >&2
    exit 1
fi
export THEOS_PACKAGE_SCHEME=roothide
make clean || true
make package messages=yes
