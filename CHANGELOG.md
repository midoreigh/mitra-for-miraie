# Changelog

What's new in each release of Mitra for MirAIe for Mac. Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html). The Android app is versioned
separately; see [its changelog](android/CHANGELOG.md).

## [Unreleased]

### What's new

- **Timers.** Click the timer button to have your AC turn off or on at a set time, or pick
  30 minutes to 4 hours from now. Your AC keeps the timers itself, so they work even while your
  Mac is asleep.
- **Sleep profiles.** Choose a temperature for each hour of the night in Settings, and whether
  the AC turns off at the end, then start the profile from the moon button. Gentle, the AC's own
  profile, is always there: your temperature for three hours, then a degree warmer, then two.
- **What's coming, at a glance.** While a timer is set or a profile runs, the panel shows it
  under the AC, such as "Off at 9:20 PM" or "Night · hour 2 of 4".

## [1.4.0] - 2026-10-31

The AC on screen now switches on and off like the real thing.

### What's new

- **A livelier power switch.** Turn your AC on and the drawn unit comes to life the way the real
  one does: the flap swings open, the fan spins up and the air gathers from the outlet while the
  display glows on. Turn it off and the air slows and fades before the flap closes.

### Fixes

- **Settings fits on your screen.** The Settings window no longer runs past the top and bottom
  of smaller screens; anything that doesn't fit scrolls.

## [1.3.0] - 2026-10-31

Clearer when your AC can't be reached, and smoother updates.

### What's new

- **Offline at a glance.** When your AC can't be reached, the whole panel shows it: the AC is
  drawn idle with its red light, a message right under it says what to check, and every control
  dims, without anything jumping around.
- **Easier updates.** Once an update has downloaded, the panel tells you exactly what's next,
  including where to click **Open Anyway** if macOS blocks the new version.
- **Try the update banner first.** In Preview Mode, choose **Preview Update Banner** from the
  right-click menu to see how updating works, without downloading anything.

## [1.2.1] - 2026-10-31

A behind-the-scenes change to how releases are signed.

### Changes

- **Releases are signed with a permanent certificate.** This was meant to stop macOS asking for
  your password after updates, but it doesn't: without a paid Apple Developer ID, macOS still
  asks after each update, usually twice, before a new version can use your saved MirAIe sign-in.
  Choose **Always Allow**. The [README](https://github.com/midoreigh/mitra-for-miraie#faq)
  explains why.

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

[1.4.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.3.0...v1.4.0
[1.3.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.2.1...v1.3.0
[1.2.1]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.2.0...v1.2.1
[1.2.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.1.0...v1.2.0
[1.1.0]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.0.0...v1.1.0
[1.0.0]: https://github.com/midoreigh/mitra-for-miraie/releases/tag/v1.0.0
