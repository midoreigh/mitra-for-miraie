# Changelog

All notable changes to this project are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions follow
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Changed

- New app icon in the app's own look: the graphite night sky, the white unit with its green
  light and open flap, and cyan air streaming out.
- Widgets redesigned to match the panel: the graphite backdrop, the drawn unit with its online
  light, the set temperature large with the room temperature under it, the round power and ±
  buttons, and fan and mode bars on the large widget.
- Tapped widget controls show as pending until the AC confirms, and temperatures roll to new
  values.

## [1.0.0] - 2026-10-30

First release of the macOS app.

### Added

- Menu bar panel with an animated AC whose airflow follows both louvers, the mode's colour and
  the fan speed.
- Power, set temperature, mode, fan speed, up/down and left/right airflow with swing, Eco,
  Powerful, Converti7, nanoe X and the display light.
- Live sync with the AC over MQTT, with an online indicator on the drawn unit.
- Room temperature as reported by the AC.
- Features shown only when the AC has them, with per-AC switches in Settings.
- Siri and Shortcuts actions.
- Desktop and Notification Center widgets and a Control Center toggle (when built from source
  with your own Apple developer team).
- Preview mode, and a demo AC to try the app without a MirAIe account.

[Unreleased]: https://github.com/midoreigh/mitra-for-miraie/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/midoreigh/mitra-for-miraie/releases/tag/v1.0.0
