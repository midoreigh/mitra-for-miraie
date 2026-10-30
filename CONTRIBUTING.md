# Contributing to Mitra for MirAIe

Thanks for your interest in improving Mitra for MirAIe. Bug reports, ideas and pull requests
are all welcome.

## Reporting bugs and asking for features

Open an [issue](https://github.com/midoreigh/mitra-for-miraie/issues/new/choose) using one of
the templates. For bugs, include your macOS version, your AC model if you know it, and the
steps that show the problem. Never include your MirAIe password or account details.

Security problems should be reported privately; see [SECURITY.md](SECURITY.md).

## Development setup

The macOS app lives in [`macOS`](macOS). You need macOS 26 and Xcode 26. See
[`macOS/README.md`](macOS/README.md) to build and run it, and to sign it with your own Apple
developer team (a free Personal Team works).

You don't need an AC to work on the interface: on the sign-in screen, choose **Try it without
an account** to get a demo AC. When signed in, right-click the menu bar icon and choose
**Preview Mode** to try controls without sending anything to your AC.

Run the package tests before opening a pull request:

```sh
cd macOS/Packages/MitraKit && swift test
```

## Pull requests

`main` is protected: changes go in through pull requests. For now CI builds and tests the app
only for release-prep pull requests (`release/…` branches) and when run by hand from the Actions
tab, so build and test your change locally before opening a pull request.

1. Fork the repository and create a branch from `main`.
2. Keep each pull request to one change, and describe what it does and why.
3. Match the style of the surrounding code: Swift 6, SwiftUI, small focused types, and comments
   that explain why rather than what.
4. Add or update tests for logic in `MitraKit`, and update the READMEs and
   [CHANGELOG.md](CHANGELOG.md) (under **Unreleased**) when behaviour changes.
5. Make sure CI passes.

## Releases

Maintainers release by updating the changelog, bumping `MARKETING_VERSION`, and pushing a tag
such as `v1.1.0`. The release workflow builds the DMG and publishes it on the Releases page.

## Code of conduct

This project follows the [Code of Conduct](CODE_OF_CONDUCT.md). By taking part, you agree to
uphold it.
