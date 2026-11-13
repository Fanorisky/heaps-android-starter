#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
haxe test.hxml
