#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/../.."
platform_java_directory="$(mktemp -d)"
trap 'rm -rf "$platform_java_directory"' EXIT
javac -Xlint:all -Werror -d "$platform_java_directory" \
 app/src/main/java/io/heaps/android/NativeDispatch.java \
 app/src/main/java/io/heaps/android/SessionDispatch.java \
 app/src/main/java/io/heaps/android/RouteTracker.java \
 tests/platform/java/io/heaps/android/DispatchTest.java
java -ea -cp "$platform_java_directory" io.heaps.android.DispatchTest
