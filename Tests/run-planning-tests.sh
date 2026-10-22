#!/bin/sh
set -eu
cd "$(dirname "$0")/.."
build_dir=$(mktemp -d "${TMPDIR:-/tmp}/orbisol-tests.XXXXXX")
trap 'rm -rf "$build_dir"' EXIT HUP INT TERM
xcrun swiftc -module-cache-path "$build_dir/modules" \
  Tests/PlanningTests.swift MeteoHeure/Models/Planning.swift \
  MeteoHeure/Models/WeatherResponse.swift MeteoHeure/Models/Location.swift \
  MeteoHeure/Models/ProductPlanning.swift -o "$build_dir/planning-tests"
"$build_dir/planning-tests" "$@"
