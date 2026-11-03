#!/usr/bin/env bash
# Builds an UNSIGNED .ipa of THE WAITING. Runs on macOS only.
#
#   tools/ios/build_unsigned_ipa.sh
#
# Environment (all optional):
#   GODOT       path to the Godot 4.7.2 binary
#               (default: /Applications/Godot.app/Contents/MacOS/Godot)
#   BUNDLE_ID   bundle identifier to build with (default: from export_presets.cfg)
#   TEAM_ID     Apple Developer Team ID, only if Godot insists on one for the
#               Xcode project (default: from export_presets.cfg; no value is
#               ever invented)
#   OUT         output .ipa (default: build/ios/TheWaiting-unsigned.ipa)
#
# What it does:
#   1. checks macOS, Xcode, Godot 4.7.2 and its iOS export templates;
#   2. copies the project to a temporary folder — the real project is never
#      modified;
#   3. in that copy only, sets the iOS preset to "export Xcode project only"
#      (Godot's own IPA step insists on signing), and applies BUNDLE_ID /
#      TEAM_ID if given;
#   4. exports the Xcode project with Godot;
#   5. builds it for devices with signing switched off (xcodebuild);
#   6. wraps the .app in Payload/ and zips it as an .ipa.
# The result is unsigned: sign it yourself (e.g. with your certificate and a
# provisioning profile) before installing it on a device.

set -euo pipefail

GODOT_VERSION_EXPECTED="4.7.2.stable"
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
OUT="${OUT:-$ROOT/build/ios/TheWaiting-unsigned.ipa}"
TEMPLATES="$HOME/Library/Application Support/Godot/export_templates/$GODOT_VERSION_EXPECTED/ios.zip"

fail() { echo "error: $*" >&2; exit 1; }
step() { echo; echo "==> $*"; }

step "Checking the build machine"
[[ "$(uname -s)" == "Darwin" ]] || fail "this script needs macOS (found $(uname -s))."
command -v xcodebuild >/dev/null || fail "xcodebuild not found. Install Xcode, then: sudo xcode-select -s /Applications/Xcode.app"
# Read whole outputs (sed -n 1p), never cut a pipe short (head): with
# pipefail, a writer killed by SIGPIPE fails the build.
xcodebuild -version | sed -n 1p
xcrun --sdk iphoneos --show-sdk-version >/dev/null 2>&1 || fail "the iOS SDK is missing. Open Xcode once and install the iOS platform (Settings → Components)."
[[ -x "$GODOT" ]] || fail "Godot not found at $GODOT (set GODOT=/path/to/Godot)."
GODOT_VERSION="$("$GODOT" --version 2>/dev/null | sed -n 1p)"
echo "Godot $GODOT_VERSION"
[[ "$GODOT_VERSION" == "$GODOT_VERSION_EXPECTED"* ]] || fail "this project is made with Godot $GODOT_VERSION_EXPECTED; found $GODOT_VERSION."
[[ -f "$TEMPLATES" ]] || fail "iOS export templates missing: $TEMPLATES
  In Godot: Editor → Manage Export Templates → Download and Install (version $GODOT_VERSION_EXPECTED)."

WORK="$(mktemp -d -t thewaiting-ios)"
trap 'echo "(work folder kept for inspection: $WORK)"' ERR

step "Copying the project to $WORK (the original is not touched)"
mkdir -p "$WORK/project"
rsync -a --exclude ".godot/" --exclude "build/" --exclude ".git/" "$ROOT/" "$WORK/project/"

step "Preparing the copy's iOS preset for an unsigned build"
PRESETS="$WORK/project/export_presets.cfg"
[[ -f "$PRESETS" ]] || fail "export_presets.cfg not found in the project."
# Settings applied to the copy only. Missing values are reported, never made up.
awk -v bundle="${BUNDLE_ID:-}" -v team="${TEAM_ID:-}" '
	BEGIN { in_opts = 0 }
	/^\[preset\.0\.options\]/ { print; in_opts = 1;
		print "application/export_project_only=true"; next }
	/^\[/ { in_opts = 0 }
	in_opts && /^application\/export_project_only=/ { next }
	in_opts && team != "" && /^application\/app_store_team_id=/ { print "application/app_store_team_id=\"" team "\""; next }
	in_opts && bundle != "" && /^application\/bundle_identifier=/ { print "application/bundle_identifier=\"" bundle "\""; next }
	{ print }
' "$PRESETS" > "$PRESETS.tmp" && mv "$PRESETS.tmp" "$PRESETS"
# Build logs may be public: show whether a Team ID is set, never its value.
grep -E "^application/(bundle_identifier|export_project_only|short_version)=" "$PRESETS"
if grep -q '^application/app_store_team_id=".\+"' "$PRESETS"; then echo 'application/app_store_team_id=(set)'; fi
if grep -q '^application/bundle_identifier="com.example' "$PRESETS"; then
	echo "warning: the bundle identifier is still the placeholder com.example.thewaiting — set BUNDLE_ID (or the preset) before signing."
fi
if grep -q '^application/app_store_team_id=""' "$PRESETS"; then
	echo "note: no App Store Team ID set (TEAM_ID). Fine for an unsigned build unless Godot requires it below."
fi

step "Importing resources"
"$GODOT" --headless --path "$WORK/project" --import >/dev/null 2>&1 || true

step "Exporting the Xcode project with Godot"
mkdir -p "$WORK/xcode"
"$GODOT" --headless --path "$WORK/project" --export-release "iOS" "$WORK/xcode/TheWaiting.ipa" 2>&1 | tee "$WORK/export.log" || true
XCPROJ="$(find "$WORK/xcode" -maxdepth 1 -name "*.xcodeproj" -print -quit)"
if [[ -z "$XCPROJ" ]]; then
	if grep -qi "team id" "$WORK/export.log"; then
		fail "Godot requires an App Store Team ID even for this unsigned export. Set TEAM_ID (in GitHub Actions: the repository secret IOS_TEAM_ID) to your Apple Developer Team ID."
	fi
	fail "Godot did not produce an Xcode project (see the export output above)."
fi
echo "Xcode project: $XCPROJ"

step "Building for iOS devices without signing"
SCHEME="$(xcodebuild -list -project "$XCPROJ" 2>/dev/null | awk '/Schemes:/{f=1;next} f&&NF&&!done{gsub(/^ +/,"");print;done=1}')"
[[ -n "$SCHEME" ]] || SCHEME="$(basename "$XCPROJ" .xcodeproj)"
echo "Scheme: $SCHEME"
xcodebuild \
	-project "$XCPROJ" \
	-scheme "$SCHEME" \
	-configuration Release \
	-sdk iphoneos \
	-destination "generic/platform=iOS" \
	-derivedDataPath "$WORK/derived" \
	CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" DEVELOPMENT_TEAM="" \
	build > "$WORK/xcodebuild.log" 2>&1 || { tail -80 "$WORK/xcodebuild.log"; fail "xcodebuild failed (last lines above)."; }
tail -5 "$WORK/xcodebuild.log"

APP="$(find "$WORK/derived/Build/Products/Release-iphoneos" -maxdepth 1 -name "*.app" -print -quit)"
[[ -n "$APP" ]] || fail "xcodebuild did not produce an .app."

step "Packaging the unsigned IPA"
mkdir -p "$WORK/ipa/Payload" "$(dirname "$OUT")"
cp -R "$APP" "$WORK/ipa/Payload/"
rm -f "$OUT"
(cd "$WORK/ipa" && zip -qry "$OUT" Payload)
echo "Unsigned IPA: $OUT ($(du -h "$OUT" | cut -f1))"
echo "Contents check:"
unzip -l "$OUT" | awk 'NR>3 && /Payload\/[^/]+\.app\/[^/]+$/ && n < 8 {print "  " $4; n++}'
rm -rf "$WORK"
trap - ERR
echo
echo "Done. The IPA is NOT signed; sign it before installing on a device."
