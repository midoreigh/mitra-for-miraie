# Changelog

What's new in each release of Mitra for MirAIe. Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### What's new

- **Mitra for Android.** The same living picture of your AC and one-tap controls for every
  mode, fan speed and louver direction, now on Android phones, with a home-screen widget, a
  Quick Settings tile for power and shortcuts when you long-press the app icon. Try it without
  an account from the sign-in screen.

### Changed

- When your AC is offline, the whole panel says so: the warning sits across the top, the AC is
  drawn idle with its red light, and all the controls are dimmed.
- After downloading an update, the panel reminds you that macOS may ask you to click Open
  Anyway in System Settings ▸ Privacy & Security before the new version opens.

## [1.2.1] - 2026-10-31

Fewer interruptions when you update.

### Fixes

- **No more keychain prompts after updates.** Updating used to make macOS ask again, with Touch
  ID or your password, before Mitra could use your saved MirAIe login. From now on, updates
  keep that permission. You may be asked one last time when you update to this version.

## [1.2.0] - 2026-10-31

A warmer look for the display light.

### What's new

- **The Display button glows like a lit bulb.** When the AC's display is on, its button now
  shines a warm, incandescent amber.

## [1.1.0] - 2026-10-31

Mitra now tells you when there's a new version, and the air in the panel moves more like the real
thing.

### What's new

- **Updates, built in.** Mitra checks for new versions once a day. When one is out, a banner in
  the panel offers it: one click downloads it and opens the installer, and you drag the app into
  Applications. You can also choose **Check for Updates…** from the right-click menu, see your
  version in Settings, or turn automatic checks off there.
- **Air that changes the way real air does.** Switch mode or fan speed and the change starts at
  the AC: new air comes out in the new colour and at the new speed, and gradually fills the room
  while the air already blowing carries on. No more jumps when you switch modes.

### Fixes

- The Settings window no longer shows a scroll bar when everything already fits.

## [1.0.0] - 2026-10-31

Your Panasonic AC, right in your Mac's menu bar. This is the first release of Mitra for MirAIe
for the Mac.

### What's new

- **Go straight to the setting you want.** In the MirAIe app you step through modes, fan speeds
  and air directions one tap at a time to reach the one you want. In Mitra every option is on
  screen, so any of them is one click away.
- **Your AC in the menu bar.** Click the icon and the whole AC is there, with the set temperature
  beside the icon at a glance.
- **A living picture of your AC.** The panel draws your unit blowing air: the flap tilts, the air
  sweeps up and down and side to side at the unit's own pace, takes the mode's colour, and drifts
  on Quiet or rushes on High.
- **Always in sync.** Changes from the remote or the MirAIe app appear within a second or two,
  and a light on the drawn unit shows whether your AC is online.
- **Siri and Shortcuts.** Control your AC by voice, or automate it with Shortcuts.
- **Try it before you sign in.** A demo AC shows everything without a MirAIe account.

### Features

- Power, and set temperature from 16 to 30 °C, with the room temperature your AC measures.
- Modes: Auto, Cool, Dry and Fan, plus Heat on units that have it.
- Fan speed: Auto, Quiet, Low, Medium and High.
- Up/down and left/right airflow: swing, or any of five positions on each.
- Eco, Powerful, Converti7 cooling levels, nanoe X on units that have it, and the display light.
- Every AC on your MirAIe account, one click apart.
- Siri and Shortcuts actions for power, temperature, mode, fan speed, airflow and status.
- Preview Mode, to try controls without touching your AC.
- Only what your AC has: Heat and nanoe X appear when your unit reports them, with per-AC
  switches in Settings.
- Launch at login, and a right-click menu for Refresh, Settings, Sign Out and Quit.
- Your password stays in your Mac's Keychain and is only sent to MirAIe.

### Good to know

- Requires macOS 26 or later, on Apple silicon or Intel.
- Desktop and Notification Center widgets and the Control Center toggle are available when you
  build Mitra from source with your own Apple developer account.

[Unreleased]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.2.1...HEAD
[1.2.1]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/midoreigh/mitra-for-miraie/releases/tag/v1.0.0
