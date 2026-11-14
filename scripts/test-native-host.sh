#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tests/platform/run-native.sh
mkdir -p build/host-tests
c++ -std=c++11 -pthread -fsanitize=address,undefined -fno-omit-frame-pointer \
  app/src/main/cpp/audio/tests/gate_test.cpp app/src/main/cpp/audio/gate_controller.cpp \
  -o build/host-tests/audio-gate
build/host-tests/audio-gate

tests/audio/run-heaps-hooks.sh
