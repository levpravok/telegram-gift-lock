#!/bin/bash
# Run from anywhere. Pass a booted iPhone simulator UUID as argument 1.
set -euo pipefail
project_dir="$(cd "$(dirname "$0")/.." && pwd)"
device="${1:-booted}"
capture_dir="${2:-$project_dir/Capture}"
mkdir -p "$capture_dir"
capture_dir="$(cd "$capture_dir" && pwd)"

xcodebuild -project "$project_dir/GiftLock.xcodeproj" -scheme GiftLock \
  -sdk iphonesimulator -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$capture_dir/Build" CODE_SIGNING_ALLOWED=NO build
xcrun simctl install "$device" "$capture_dir/Build/Build/Products/Debug-iphonesimulator/GiftLock.app"
xcrun simctl terminate "$device" org.example.GiftLockPrototype 2>/dev/null || true
xcrun simctl status_bar "$device" override --time '9:41' --dataNetwork wifi \
  --wifiMode active --wifiBars 3 --batteryState charged --batteryLevel 100
xcrun simctl io "$device" recordVideo --codec=h264 --force "$capture_dir/GiftLock.mov" &
record_pid=$!
trap 'kill -INT "$record_pid" 2>/dev/null || true' EXIT
sleep 1
xcrun simctl launch "$device" org.example.GiftLockPrototype --demo-tour
sleep 29
kill -INT "$record_pid"
wait "$record_pid" || true
trap - EXIT

# Frame the actual recording and keep the final submission below 30 seconds.
swift "$project_dir/Scripts/FrameVideo.swift" "$capture_dir/GiftLock.mov" \
  "$capture_dir/GiftLock-Framed.mp4" 1.5 28
swift "$project_dir/Scripts/CompressVideo.swift" "$capture_dir/GiftLock-Framed.mp4" \
  "$capture_dir/GiftLock-Demo.mp4"
printf 'Saved video: %s\n' "$capture_dir/GiftLock-Demo.mp4"
