#!/bin/bash
set -euo pipefail
project_dir="$(cd -- "$(dirname -- "$0")" && pwd)"
identity="${CONTROLGAME_SIGNING_IDENTITY:-}"
if [[ -z "$identity" ]]; then
  if [[ "${CONTROLGAME_ALLOW_ADHOC:-0}" != "1" ]]; then
    echo 'Configura CONTROLGAME_SIGNING_IDENTITY; para prueba temporal usa CONTROLGAME_ALLOW_ADHOC=1. La firma temporal puede invalidar permisos al recompilar.' >&2
    exit 1
  fi
  identity='-'
fi
xcrun --find swiftc >/dev/null
mkdir -p "$project_dir/build"
staging="$(mktemp -d "$project_dir/build/candidate.XXXXXX")"
trap 'rm -rf "$staging"' EXIT
app="$staging/ControlGame.app"
mkdir -p "$app/Contents/MacOS"
cp "$project_dir/Info.plist" "$app/Contents/Info.plist"
xcrun swiftc -O "$project_dir/main.swift" "$project_dir/SpatialNavigation.swift" "$project_dir/RuntimeMath.swift" "$project_dir/Doctor.swift" -o "$app/Contents/MacOS/ControlGame" -framework Cocoa -framework GameController -framework ApplicationServices
plutil -lint "$app/Contents/Info.plist"
codesign --force --sign "$identity" "$app"
codesign --verify --strict "$app"
if [[ -e "$project_dir/build/ControlGame.app" ]]; then
  backup="$(mktemp -d "$project_dir/build/previous.XXXXXX")"
  mv "$project_dir/build/ControlGame.app" "$backup/ControlGame.app"
fi
mv "$app" "$project_dir/build/ControlGame.app"
echo "Build: $project_dir/build/ControlGame.app"
