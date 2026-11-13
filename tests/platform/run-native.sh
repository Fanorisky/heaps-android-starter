#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
platform_test_directory="$(mktemp -d)"
trap 'rm -rf "$platform_test_directory"' EXIT
platform_sanitizers=()
if [[ "${SANITIZE:-1}" == 1 ]]; then platform_sanitizers=(-fsanitize=address,undefined -fno-omit-frame-pointer); fi
"${CXX:-c++}" -std=c++11 -pthread -Wall -Wextra -Werror "${platform_sanitizers[@]}" \
    -Iapp/src/main/cpp/platform -Ivendor/hashlink/libs/sdl -Ivendor/sdl/src/core/android \
    tests/platform/native_test.cpp -o "$platform_test_directory/platform-test"
"$platform_test_directory/platform-test"
