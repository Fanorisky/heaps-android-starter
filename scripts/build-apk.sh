#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
variant=proof
if [[ "${1:-}" == --variant=* ]]; then variant="${1#--variant=}"; shift; fi
case "$variant" in proof) build_task=assembleProof ;; debug) build_task=assembleDebug ;; *) exit 2 ;; esac
./scripts/setup-toolchain.sh
./scripts/test-pure.sh
./scripts/test-native-host.sh
./scripts/generate-assets.sh --check
./scripts/generate-hlc.sh
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
./gradlew ":app:$build_task" "$@"
mkdir -p dist
cp "app/build/outputs/apk/$variant/app-$variant.apk" dist/heaps-android-proof.apk
sha256sum dist/heaps-android-proof.apk > dist/heaps-android-proof.apk.sha256
if [[ "$variant" == proof ]]; then
  python3 scripts/verify-apk.py dist/heaps-android-proof.apk --expected-cert "$(cat docs/signing/test-certificate-sha256.txt)"
else
  python3 scripts/verify-apk.py dist/heaps-android-proof.apk
fi
printf 'APK: %s/dist/heaps-android-proof.apk\n' "$PWD"
