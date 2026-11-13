#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
haxe test.hxml
haxe platform-test.hxml
haxe -cp lib -cp tests/audio -main AudioPolicyTest --interp
haxe -cp lib -cp tests/storage -main StorageTest --interp
haxe -cp vendor/heaps -cp lib -cp src -cp tests/storage -main LegacySaveTest --interp
haxe -cp lib -cp src -cp tests/demo -main EditorTest --interp
haxe -cp lib -cp src -cp tests/demo -main GameEventTest --interp
haxe -cp lib -cp src -cp tests/demo -main SettingsTest --interp
