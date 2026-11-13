#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p build/hlc
haxe game.hxml
printf 'Generated native C in build/hlc/game.c\n'
