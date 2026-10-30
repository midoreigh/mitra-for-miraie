# Mitra for MirAIe for Android

Native Kotlin and Jetpack Compose. Needs Android 8.0 or later.

```bash
cd android
./gradlew installDebug        # build and install on a connected phone
./gradlew testDebugUnitTest   # unit tests
```

Builds with JDK 21 or later (Android Studio's bundled JDK works:
`export JAVA_HOME="/Applications/Android Studio.app/Contents/jbr/Contents/Home"`).

- `model/`: AC state, commands and capabilities, shared logic with the Mac app's MitraKit.
- `miraie/`: MirAIe sign-in, REST API and a small MQTT-over-TLS client.
- `store/`: the app's live state and encrypted (Android Keystore) credential storage.
- `ui/`: the animated AC hero and controls.
- `widget/`: home-screen widget and Quick Settings tile.

The big temperature uses [Nunito](https://github.com/googlefonts/nunito), under the SIL Open
Font License (`licenses/Nunito-OFL.txt`).
