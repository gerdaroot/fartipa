#!/bin/bash
# Builds one scheme quietly. On failure the compile errors go to the job's annotations
# and to build-errors.txt, because raw Actions logs cannot be read without signing in.
# Usage: xcbuild.sh <scheme> <configuration> [extra xcodebuild arguments]
set -uo pipefail

scheme="$1"
configuration="$2"
shift 2
log="build-$scheme.log"

xcodebuild build \
  -project PoopDraw.xcodeproj \
  -scheme "$scheme" \
  -configuration "$configuration" \
  -derivedDataPath build \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  "$@" > "$log" 2>&1
status=$?

if [ "$status" -ne 0 ]; then
  grep -E "error:|BUILD FAILED" "$log" | sort -u >> build-errors.txt
  grep -E "error:" "$log" | sort -u | head -10 | while read -r line; do
    echo "::error::$line"
  done
  tail -30 "$log"
fi
exit "$status"
