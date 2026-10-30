# Mitra for MirAIe

[![CI](https://github.com/midoreigh/mitra-for-miraie/actions/workflows/ci.yml/badge.svg)](https://github.com/midoreigh/mitra-for-miraie/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/midoreigh/mitra-for-miraie)](https://github.com/midoreigh/mitra-for-miraie/releases/latest)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

**The most beautiful and feature-rich MirAIe controller for the Mac.**

Control your Panasonic MirAIe air conditioners from the menu bar, with Siri, from widgets and
from Control Center. Native, written entirely in Swift and SwiftUI.

<!-- demo video -->

## Install

1. Download the latest **Mitra-for-MirAIe-<version>.dmg** from
   [Releases](https://github.com/midoreigh/mitra-for-miraie/releases/latest), open it, and drag
   **Mitra for MirAIe** into **Applications**.
2. Open it from Applications. The first time, macOS says it can't verify the app, because it
   isn't signed with a paid Apple Developer ID. Click **Done**, then go to **System Settings ▸
   Privacy & Security**, scroll down and click **Open Anyway**. You only need to do this once.
3. Click the AC icon in the menu bar and sign in with your MirAIe mobile number or email, or
   choose **Try it without an account** to look around first.

Requires macOS 26 or later, on Apple silicon or Intel. To update, download the new DMG and
replace the app. Downloaded builds don't include the widgets and Control Center toggle (they
need a paid Apple signature to share your sign-in); [build from source](macOS/README.md) with
your own Apple developer team to get them.

## Platforms

| Platform | Status | Folder |
|---|---|---|
| macOS 26 or later | Available | [`macOS`](macOS) |
| iOS | Planned | |
| Android | Planned | |

## The Mac app

- **A living AC.** The menu bar panel shows your unit blowing air that follows its louvers:
  the flap tilts and the air sweeps up and down and left and right, at the pace of the real
  unit. The air takes the mode's colour and moves at the fan's speed, from a slow drift on
  Quiet to a rush on High.
- **Every control.** Power, set temperature, mode, fan speed (Auto, Quiet, Low, Medium, High),
  up/down and left/right airflow with swing, Eco, Powerful, Converti7 cooling levels, nanoe X
  and the display light.
- **Always in sync.** Changes made with the remote or the MirAIe app appear within a second or
  two. The light on the drawn unit shows whether the AC is online.
- **Room temperature** as reported by the AC, alongside the set temperature.
- **Only what your AC has.** Heating and nanoe X appear only when your unit reports them, and
  can be switched on or off per AC in Settings.
- **Siri and Shortcuts.** "Turn on the AC in Mitra for MirAIe", "Make it cooler with Mitra for
  MirAIe", "Switch Mitra for MirAIe to Dry" and more. Every action is also available in the
  Shortcuts app, so you can schedule your AC with Shortcuts automations.
- **Widgets** for the desktop and Notification Center, with working buttons, and a power toggle
  for Control Center (when built from source).
- **Every AC in the house.** Switch between all the ACs on your MirAIe account.
- **Try it without an account.** The sign-in screen opens a demo AC with every control
  working. Signed in, right-click the menu bar icon for Preview Mode, to try controls without
  sending anything to your AC.

Right-click the menu bar icon for Refresh, Settings, Sign Out and Quit.

See [`macOS/README.md`](macOS/README.md) to build and run it.

## Contributing

Bug reports, ideas and pull requests are welcome. See [CONTRIBUTING.md](CONTRIBUTING.md), and
please follow the [Code of Conduct](CODE_OF_CONDUCT.md). Report security problems privately;
see [SECURITY.md](SECURITY.md).

## Privacy

You sign in with the same mobile number or email and password as the MirAIe app. Your password
is stored in your Mac's Keychain and is only ever sent to MirAIe.

## License

[MIT](LICENSE) © 2026 Mido Reigh.

## Disclaimer

Mitra for MirAIe is an unofficial app. It isn't affiliated with or endorsed by Panasonic.
MirAIe is a trademark of Panasonic.
