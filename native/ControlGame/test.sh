#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
test_dir="$(mktemp -d "${TMPDIR:-/tmp}/controlgame-tests.XXXXXX")"
trap 'rm -rf "$test_dir"' EXIT
xcrun swiftc "$project_dir/RuntimeMath.swift" "$project_dir/tests/main.swift" -o "$test_dir/runtime-tests"
"$test_dir/runtime-tests"
bash -n "$project_dir/build.sh"
plutil -lint "$project_dir/Info.plist"
