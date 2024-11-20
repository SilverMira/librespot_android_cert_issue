# ANDROID
ARG BUILD_BASE_TAG
FROM $BUILD_BASE_TAG AS flutter-android-install
RUN rustup target add aarch64-linux-android \
  armv7-linux-androideabi \
  x86_64-linux-android \
  i686-linux-android
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator
RUN apt-get update
RUN apt-get install -y \
  sdkmanager openjdk-17-jdk \
  cmake libclang-dev \
  gcc-multilib
ARG ANDROID_SDK_VERSION="33"
ARG ANDROID_NDK_VERSION="23.1.7779620"
RUN sdkmanager "cmdline-tools;latest" "platform-tools" "platforms;android-$ANDROID_SDK_VERSION" "ndk;$ANDROID_NDK_VERSION"
RUN yes | sdkmanager --licenses
RUN cargo install --force --locked bindgen-cli
ENV ANDROID_NDK_ROOT=$ANDROID_HOME/ndk/$ANDROID_NDK_VERSION
RUN flutter precache --android
RUN flutter doctor --verbose

FROM flutter-android-install AS flutter-android-build
ARG BUILD_CONFIGURATION="release"
ARG TARGET_ARCH="android-arm,android-arm64,android-x64"
WORKDIR /src
COPY . .
RUN mkdir -p ./android/app/src/main/jniLibs/armeabi-v7a
RUN mkdir -p ./android/app/src/main/jniLibs/arm64-v8a
RUN mkdir -p ./android/app/src/main/jniLibs/x86
RUN mkdir -p ./android/app/src/main/jniLibs/x86_64
RUN cp -f $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/arm-linux-androideabi/libc++_shared.so ./android/app/src/main/jniLibs/armeabi-v7a/libc++_shared.so
RUN cp -f $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/aarch64-linux-android/libc++_shared.so ./android/app/src/main/jniLibs/arm64-v8a/libc++_shared.so
RUN cp -f $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/i686-linux-android/libc++_shared.so ./android/app/src/main/jniLibs/x86/libc++_shared.so
RUN cp -f $ANDROID_NDK_ROOT/toolchains/llvm/prebuilt/linux-x86_64/sysroot/usr/lib/x86_64-linux-android/libc++_shared.so ./android/app/src/main/jniLibs/x86_64/libc++_shared.so
RUN flutter build apk --$BUILD_CONFIGURATION --target-platform $TARGET_ARCH

FROM scratch AS flutter-android
COPY --from=flutter-android-build /src/build/app/outputs/flutter-apk/ /
