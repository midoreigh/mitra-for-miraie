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

## Layout

| Path | What's there |
|---|---|
| `Packages/MitraKit` | `MitraKit`: device models, the MirAIe REST and MQTT client, shared storage and `MirAIeService`. `MitraUI`: the animated AC unit, theme and hover hints. |
| `App` | The menu bar app: `ACStore` (the live connection), the panel, Settings and the right-click menu. |
| `Shared` | App Intents and entities, compiled into both the app and the widgets. |
| `Widgets` | The WidgetKit extension and the Control Center control. |
| `Config` | Info.plists, entitlements and signing settings. |
| `scripts/make-icon.swift` | Redraws the app icon. |

New kinds of device can be added next to `ACState` and `ACCommand`; `DeviceKind` and `Device`
already carry the kind.

## How it talks to MirAIe

MirAIe has no public API. The app signs in over REST, then sends commands and receives status
over MQTT (`mqtt.miraie.in:8883`), as the MirAIe app does. Commands update the panel at once;
the AC's own status reports then confirm them.
