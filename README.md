# librespot_android_cert_issue

## Reproduction steps on Android

1. Try using `flutter run` with an android emulator connected, if that doesn't
work, continue with steps below to use docker to build the app.
2. This repo uses `just` to run commands,
`just --set BUILD_CONFIGURATION debug --set ANDROID_ARCH android-arm,android-arm64,android-x64 build-android`
will build the app in docker and output the APK files in `./build/docker/android/`.
3. Use `adb install` to install the APK on the device.
4. Launch the app and `just log-android` will display logcat entries
only for the app.
5. Within the app, enter the access token and track ID, click `Create` and
a librespot player will be spawned to play the track.
6. Observe the logs

## Other platforms

The app does build for other platforms, and does work as expected on Windows/Linux.

1. `just build-linux` will build the app executable in Docker and place the
bundle in `./build/docker/linux`
2. Run the binary with `RUST_LOG=trace ./frb_base`
