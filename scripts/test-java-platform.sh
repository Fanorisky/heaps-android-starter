#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
tests/platform/run-java.sh
