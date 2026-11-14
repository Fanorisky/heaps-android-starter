#!/usr/bin/env bash
# Real ALC/error integration with a host OpenAL null backend; no hardware claim.
set -euo pipefail
cd "$(dirname "$0")/../.."
mkdir -p build/host-tests
c++ -std=c++11 -pthread -DLIBHL_STATIC \
  -Ivendor/hashlink/src -Ivendor/openal/include -Iapp/src/main/cpp/include \
  app/src/main/cpp/audio/tests/alc_health_test.cpp \
  app/src/main/cpp/audio/gate.cpp app/src/main/cpp/audio/gate_controller.cpp \
  -l:libopenal.so.1 -o build/host-tests/audio-alc-health
ALSOFT_DRIVERS=null build/host-tests/audio-alc-health
