# Mitra for MirAIe for Android

Native Kotlin and Jetpack Compose. Needs Android 8.0 or later.

```bash
cd android
./gradlew installDebug        # build and install on a connected phone
./gradlew testDebugUnitTest   # unit tests
```

Releases are versioned separately from the Mac app (see [CHANGELOG.md](CHANGELOG.md)): bump
`versionName` and `versionCode` in `app/build.gradle.kts` in a `release/android-<version>` pull
request, which CI builds, then push an `android-v<version>` tag. The release workflow builds the
APK signed with the permanent release key from the repository secrets and publishes it, as a
pre-release when the version has a suffix such as `-rc.1`.

Builds with JDK 21 or later (Android Studio's bundled JDK works:
`export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`).

- `model/`: AC state, commands and capabilities, shared logic with the Mac app's MitraKit.
- `miraie/`: MirAIe sign-in, REST API and a small MQTT-over-TLS client.
- `store/`: the app's live state and encrypted (Android Keystore) credential storage.
- `ui/`: the animated AC hero and controls.
- `widget/`: home-screen widget and Quick Settings tile.

`scripts/make-showcase.swift` builds the README's showcase images from full-resolution S24 Ultra
screenshots, in the Mac images' style: each in a phone frame on a navy card, with a headline and a
description line.

The big temperature uses [Nunito](https://github.com/googlefonts/nunito), under the SIL Open
Font License (`licenses/Nunito-OFL.txt`).
