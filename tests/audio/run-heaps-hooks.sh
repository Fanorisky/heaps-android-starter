#!/usr/bin/env bash
# Actual patched Heaps CPU clocks/callbacks; no audio playback or hardware claim.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/host-tests
hook_source="${1:-vendor/heaps}"
haxe -cp vendor/format -cp vendor/heaps -cp tests/audio -cp "$hook_source" \
  -main HeapsAudioHooksTest -D heapsandroid_audio_hooks -dce full \
  -js build/host-tests/heaps-audio-hooks.js
node build/host-tests/heaps-audio-hooks.js
