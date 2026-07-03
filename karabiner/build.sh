#!/usr/bin/env bash
set -euo pipefail

APP_NAME="FnMediaControl"
APP_DIR=".bin/${APP_NAME}.app"
APP_BIN="${APP_DIR}/Contents/MacOS/media-control"
SIGNING_IDENTITY="${SIGNING_IDENTITY:-Apple Development: Samuel DeSota (96ATCKZ87A)}"

mkdir -p "${APP_DIR}/Contents/MacOS" "${APP_DIR}/Contents/Resources"

swiftc src/media-control.swift -o .bin/media-control
cp .bin/media-control "${APP_BIN}"
cp src/FnMediaControl-Info.plist "${APP_DIR}/Contents/Info.plist"

/usr/bin/codesign \
  --force \
  --sign "${SIGNING_IDENTITY}" \
  --timestamp=none \
  "${APP_DIR}"

tsx src/index.ts
