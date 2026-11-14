#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
export ANDROID_HOME="${ANDROID_HOME:-/opt/android-sdk}"
# The fault fixture exercises genuine ALC errors only in this explicitly enabled
# build. It is not part of the published proof variant's default definitions.
./gradlew :app:assembleDebug -PandroidAudioFaultTests=true -PandroidAbis=x86_64 -Papp.application_id=io.heaps.android.healthfixture "$@"
python3 scripts/test-android.py app/build/outputs/apk/debug/app-debug.apk --audio-only
