# Changelog

What's new in each release of Mitra for MirAIe for Android. It's versioned separately from the
Mac app, and released under tags named `android-v<version>`. Versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [1.0.2] - 2026-10-31

### What's new

- **A new icon.** Your AC with its air in every mode's colour: Heat, Auto, Cool, Dry and Fan.

## [1.0.1] - 2026-10-31

### Fixes

- **A neater Converti7 picker.** Tapping Converti7 now opens a glass strip just above the
  button with every cooling level in one row; tap one to pick it.
- **Tell AC on and AC off apart.** When you long-press the app icon, AC off now has its own
  grey, struck-through icon instead of the same one as AC on.

## [1.0.0] - 2026-10-31

The first full release of Mitra for Android, now with timers and sleep profiles.

### What's new

- **Timers.** Tap Timer to have your AC turn off later, say in an hour, or turn on in the
  morning. The AC keeps its timers itself, so they work even while your phone is off.
- **Sleep profiles.** Set a temperature for each hour of the night in Settings, then start the
  profile with the Sleep button and your AC follows it on its own. Gentle, built into the AC,
  keeps your temperature for three hours, then warms it a degree, then another, and turns off.
- What's set shows under the AC, such as "Off at 9:20 PM".
- **Watch your AC switch on and off.** Turning on, the flap swings open, the fan spins up and
  the air gathers from the outlet while the display glows up. Turning off, the air slows and
  fades before the flap closes, just like the real unit.

### Fixes

- **An AC without power now shows as offline.** During a power cut, Mitra could still show your
  AC as online. It now shows it offline within about a minute, and online again a few seconds
  after the power comes back. The widget, Quick Settings tile and shortcuts only count the AC as
  online when it actually answers.
- **Offline at a glance.** While your AC can't be reached, it's drawn idle with its red light and
  no air, and the temperature and every control fade, so it's clear nothing can be changed.

## [1.0.0-rc.1] - 2026-10-31

The first release candidate of Mitra for Android. Try it and tell us what you think before
1.0.0.

### What's new

- **Your AC, alive on your phone.** The AC fills the screen with its air flowing in the
  colour of the mode, at the fan speed you set and in the direction of its louvers. All your
  controls sit together on a glass panel at the bottom, within thumb reach.
- **One tap for everything.** Power, temperature, fan speed, mode, both louvers, Eco,
  Powerful, Converti7, nanoe X and the AC's display. The fan speed and mode you've picked show
  their name; long-press any other control to see what it does.
- **Instant and live.** Changes show straight away and the app follows the AC as it changes,
  including from the remote or the MirAIe app.
- **Home screen widget, Quick Settings tile and shortcuts.** Check and switch your AC without
  opening the app, toggle power from Quick Settings, and long-press the app icon for AC on,
  AC off, Cooler and Warmer.
- **More than one AC?** Switch between them from the name at the top.
- **Try it without an account.** Explore a demo AC from the sign-in screen, or use Preview
  Mode to try controls without sending anything to your AC.
- Your password stays encrypted on your phone and is only sent to MirAIe.

### Good to know

- Requires Android 8.0 or later.
- This is a release candidate: it may still have rough edges.

[Unreleased]: https://github.com/midoreigh/mitra-for-miraie/compare/android-v1.0.2...HEAD
[1.0.2]: https://github.com/midoreigh/mitra-for-miraie/compare/android-v1.0.1...android-v1.0.2
[1.0.1]: https://github.com/midoreigh/mitra-for-miraie/compare/android-v1.0.0...android-v1.0.1
[1.0.0]: https://github.com/midoreigh/mitra-for-miraie/compare/android-v1.0.0-rc.1...android-v1.0.0
[1.0.0-rc.1]: https://github.com/midoreigh/mitra-for-miraie/releases/tag/android-v1.0.0-rc.1
