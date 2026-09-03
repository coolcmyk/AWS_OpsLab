#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
BUILD="$ROOT/lambda/.build"
rm -rf "$BUILD"
mkdir -p "$BUILD"
python3 -m pip install --disable-pip-version-check -r "$ROOT/lambda/requirements.txt" -t "$BUILD"
cp "$ROOT/lambda/handler.py" "$BUILD/handler.py"
echo "Lambda dependency bundle prepared in $BUILD"
