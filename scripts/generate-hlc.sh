#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/hlc
if [[ "${HEAPS_AUDIO_FAULT_TESTS:-false}" == true ]]; then
  haxe game.hxml -D heapsandroid_audio_fault_tests
else
  haxe game.hxml
fi
printf 'Generated native C in build/hlc/game.c\n'
