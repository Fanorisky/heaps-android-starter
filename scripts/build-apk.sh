#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/setup-toolchain.sh
./scripts/run-tests.sh
./scripts/generate-hlc.sh
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
./gradlew :app:assembleDebug "$@"
mkdir -p dist
cp app/build/outputs/apk/debug/app-debug.apk dist/neon-drift-debug.apk
sha256sum dist/neon-drift-debug.apk > dist/neon-drift-debug.apk.sha256
python3 scripts/verify-apk.py
printf 'APK: %s/dist/neon-drift-debug.apk\n' "$PWD"
