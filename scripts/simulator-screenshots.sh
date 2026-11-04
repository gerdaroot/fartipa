#!/bin/bash
# Launches a Debug simulator build on each screen and saves a screenshot of it.
# Usage: simulator-screenshots.sh <path to PoopDraw.app> <output folder>
set -euo pipefail

app_path="$1"
output="$2"
bundle_id="com.poopdraw.app"
mkdir -p "$output"

udid=$(xcrun simctl list devices available -j | python3 -c '
import json, sys
runtimes = json.load(sys.stdin)["devices"]
ios = sorted((name for name in runtimes if "iOS" in name), key=lambda n: [int(p) for p in n.split("iOS-")[1].split("-")])
phones = [d["udid"] for d in runtimes[ios[-1]] if d["name"].startswith("iPhone")]
print(phones[0])
')

xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b
xcrun simctl install "$udid" "$app_path"

for screen in menu levels free trace result; do
  xcrun simctl launch --terminate-running-process "$udid" "$bundle_id" "--demo=$screen"
  sleep 12
  xcrun simctl io "$udid" screenshot "$output/$screen.png"
done
