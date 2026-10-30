# Mitra for MirAIe: macOS

The menu bar app, widgets, Control Center control and Siri actions. Requires macOS 26 and
Xcode 26.

## Build and run

1. Open `Mitra.xcodeproj` in Xcode.
2. Add your Apple ID in **Xcode ▸ Settings ▸ Accounts** (a free Personal Team works).
3. Create `Config/Signing.local.xcconfig` containing `DEVELOPMENT_TEAM = <your Team ID>`.
   You can find the Team ID in the Accounts pane. The file is git-ignored.
4. Choose the **Mitra** scheme and press ⌘R. Click the AC icon in the menu bar and sign in with
   the mobile number or email you use in the MirAIe app.

Widgets and Siri need a signed build: the app, the widgets and the intents share your session
through an App Group and the Keychain. An unsigned build still runs the menu bar app.

From the command line:

```sh
xcodebuild -project Mitra.xcodeproj -scheme Mitra -allowProvisioningUpdates build
```

Unit tests for the shared package:

```sh
cd Packages/MitraKit && swift test
```

## Releases

`scripts/release.sh [version]` builds a universal (Apple silicon and Intel) Release, signs it ad
hoc and packages it as `build/release/Mitra-for-MirAIe-<version>.dmg`. Releases aren't signed
with an Apple Developer ID, so App Groups and Keychain sharing are unavailable; the script
removes the widget extension, which depends on them, and the app keeps its data to itself.

Pushing a tag such as `v1.1.0` runs the same script in GitHub Actions and publishes the DMG on
the Releases page, with that version's notes from `CHANGELOG.md`.

## Layout

| Path | What's there |
|---|---|
| `Packages/MitraKit` | `MitraKit`: device models, the MirAIe REST and MQTT client, shared storage and `MirAIeService`. `MitraUI`: the animated AC unit, theme and hover hints. |
| `App` | The menu bar app: `ACStore` (the live connection), the panel, Settings and the right-click menu. |
| `Shared` | App Intents and entities, compiled into both the app and the widgets. |
| `Widgets` | The WidgetKit extension and the Control Center control. |
| `Config` | Info.plists, entitlements and signing settings. |
| `scripts/release.sh` | Builds the release DMG. |
| `scripts/make-icon.swift` | Redraws the app icon. |

New kinds of device can be added next to `ACState` and `ACCommand`; `DeviceKind` and `Device`
already carry the kind.

## How it talks to MirAIe

MirAIe has no public API. The app signs in over REST, then sends commands and receives status
over MQTT (`mqtt.miraie.in:8883`), as the MirAIe app does. Commands update the panel at once;
the AC's own status reports then confirm them.
