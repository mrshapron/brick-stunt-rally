#!/usr/bin/env bash
# Re-export the iOS build (regenerates build/ios/BrickStuntRally.pck and the
# Xcode project) with the latest game code, then opens the project in Xcode.
#
# Usage:  ./export_ios.sh
# Then in Xcode press Run (Cmd+R) with your iPhone connected.
#
# Requires the local "iOS" export preset (export_presets.cfg) and the iOS
# export templates installed. Set GODOT=/path/to/godot if it's not on PATH.

cd "$(dirname "$0")" || exit 1
GODOT="${GODOT:-godot}"
PCK="build/ios/BrickStuntRally.pck"

echo "Re-exporting iOS build..."
rm -f "$PCK"
mkdir -p build/ios
# Godot writes the .pck/project before it attempts the optional Xcode archive,
# so a non-zero exit from that last step is fine as long as the .pck appears.
"$GODOT" --headless --path . --export-debug "iOS" build/ios/BrickStuntRally.xcodeproj

if [ -f "$PCK" ]; then
	echo ""
	echo "OK - updated $PCK"
	echo "Now press Run (Cmd+R) in Xcode to rebuild and install on your iPhone."
	open build/ios/BrickStuntRally.xcodeproj 2>/dev/null || true
else
	echo ""
	echo "ERROR: export did not produce $PCK - see the output above."
	exit 1
fi
