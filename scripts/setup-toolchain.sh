#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v haxe >/dev/null
command -v haxelib >/dev/null
python3 scripts/fetch-deps.py
mkdir -p .haxelib
haxelib dev format "$PWD/vendor/format"
haxelib dev heaps "$PWD/vendor/heaps"
haxelib dev hlsdl "$PWD/vendor/hashlink/libs/sdl"
haxelib dev hlopenal "$PWD/vendor/hashlink/libs/openal"
haxelib dev heapsandroid "$PWD"
python3 scripts/apply-patches.py
printf 'Repository-local Haxe libraries ready (%s).\n' "$(haxe --version)"
