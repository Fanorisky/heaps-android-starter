#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
haxe test.hxml
haxe -cp src -cp tests/gamebase -main TouchControlsTest --interp
haxe platform-test.hxml
haxe -cp lib -cp tests/audio -main AudioPolicyTest --interp
haxe -cp lib -cp tests/storage -main StorageTest --interp
haxe -cp lib -cp src -cp tests/demo -main EditorTest --interp
haxe -cp lib -cp src -cp tests/demo -main SettingsTest --interp

haxe -cp lib -cp tests/audio -main AudioPausePolicyTest --interp
python3 tests/build/test_patch_tool.py
