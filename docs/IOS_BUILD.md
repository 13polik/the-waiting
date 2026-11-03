# Building THE WAITING for iOS

## Can this Windows machine build an IPA? No.

Checked on 2026-11-03 (HP ProBook 640 G2, Windows 10 22H2 build 19045):

| Requirement | Status here |
|---|---|
| macOS | Windows 10 — not available |
| Xcode (`xcodebuild`, `xcrun`, iOS SDK, `codesign`) | not installed; cannot be installed on Windows |
| Godot 4.7.2 | installed |
| Godot 4.7.2 iOS export templates (`ios.zip`) | not installed |
| iOS export preset (`export_presets.cfg`) | present; Godot stops at the missing templates before checking more |

**The blocker:** an `.ipa` contains an iOS binary that must be compiled and
linked against Apple's iOS SDK with Apple's toolchain, which exists only in
Xcode, which runs only on macOS. Godot itself does not compile for iOS: its
iOS export writes an Xcode project and then calls `xcodebuild`. Without a Mac,
the most this machine could produce is that Xcode project — and only after
installing the iOS export templates (part of Godot's ~1 GB template download).

## The simplest workflow: one script on a Mac

Requirements on the Mac:

1. macOS with **Xcode** (open it once and install the iOS platform), then
   `sudo xcode-select -s /Applications/Xcode.app`.
2. **Godot 4.7.2** (the same version as this project) in `/Applications`.
3. Godot's **export templates for 4.7.2**: in Godot, *Editor → Manage Export
   Templates → Download and Install*.

Then, in the project folder:

```bash
tools/ios/build_unsigned_ipa.sh
```

Result: `build/ios/TheWaiting-unsigned.ipa`, **not signed**.

Options: `GODOT=/path/to/Godot` (another Godot location),
`BUNDLE_ID=com.yourname.thewaiting` (your bundle identifier),
`OUT=/path/to/file.ipa`.

The script checks every requirement first and says exactly what is missing.
It works on a temporary copy of the project, so the project itself is never
changed. In that copy only, it:

* turns on *Export Project Only* (Godot's own IPA step requires signing);
* applies `BUNDLE_ID` / `TEAM_ID` if you pass them (no value is ever made up;
  if Godot refuses to export without a Team ID, the script stops and says so);
* builds with `CODE_SIGNING_ALLOWED=NO` and packs `Payload/TheWaiting.app`
  into the `.ipa`.

## Signing (yours)

An unsigned IPA will not install on a device. Re-sign the `.app` inside it
with your certificate and a provisioning profile whose App ID matches the
bundle identifier you built with, e.g. via Xcode, Apple Configurator, or a
re-signing tool you trust. To let Xcode sign it directly instead, open the
Xcode project the script exports (kept in the work folder if you stop the
script after the export step), set your team, and *Product → Archive*.

## Before a TestFlight or App Store build

These are not needed for an unsigned test IPA, but are for distribution:

| Item | Where | Current value |
|---|---|---|
| Bundle identifier | Export preset → Application | `com.example.thewaiting` (placeholder) |
| App Store Team ID | Export preset → Application | empty (yours) |
| Version / build | Export preset → Application | `0.3.0` / `1` |
| App icon 1024×1024 | Export preset → Icons | not set (Godot falls back to the project icon) |
| Launch screen colour | Export preset → Storyboard | `#050507`, matching the game |
| Device family | Export preset | iPhone and iPad |
| Renderer | Project settings | Compatibility on iOS (see PERFORMANCE.md) |

Then test on the oldest target device following the checklist in
[PERFORMANCE.md](PERFORMANCE.md#b3-what-to-measure-on-the-first-device-builds).

## Optional: generate the Xcode project on Windows

With the iOS export templates installed in Godot on this Windows machine, the
Xcode project can be exported here (*Export Project Only*) and copied to a Mac,
where Xcode builds it. It does not remove the need for a Mac, so the script
above is the simpler route.
