# Security policy

Mitra for MirAIe handles your MirAIe sign-in, so security reports are taken seriously.

## Reporting a vulnerability

Please report vulnerabilities privately through GitHub:
[Report a vulnerability](https://github.com/midoreigh/mitra-for-miraie/security/advisories/new).
Don't open a public issue for security problems.

Include what you found, how to reproduce it, and its impact. You'll get a reply within a week,
and credit in the release notes if you'd like it.

## Supported versions

Only the latest release receives fixes.

## How credentials are handled

- Your password and session token are stored in the macOS Keychain.
- They're only sent to MirAIe's own servers (`auth.miraie.in`, `app.miraie.in` and
  `mqtt.miraie.in`), over TLS.
- The app has no analytics or telemetry and talks to no other servers.
