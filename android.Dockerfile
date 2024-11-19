# ANDROID
ARG BUILD_BASE_TAG
FROM $BUILD_BASE_TAG AS flutter-android-install
ENV ANDROID_HOME=/opt/android
ENV ANDROID_SDK_ROOT=$ANDROID_HOME
ENV PATH=${PATH}:${ANDROID_HOME}/cmdline-tools/latest/bin:${ANDROID_HOME}/platform-tools:${ANDROID_HOME}/emulator
RUN apt-get update
RUN apt-get install -y \
  sdkmanager openjdk-17-jdk
RUN rustup target add aarch64-linux-android \
  armv7-linux-androideabi \
  x86_64-linux-android \
  i686-linux-android
ARG ANDROID_SDK_VERSION="33"
ARG ANDROID_NDK_VERSION="23.1.7779620"
RUN sdkmanager "cmdline-tools;latest" "platform-tools" "platforms;android-$ANDROID_SDK_VERSION" "ndk;$ANDROID_NDK_VERSION"
RUN yes | sdkmanager --licenses
RUN flutter precache --android
RUN flutter doctor --verbose

FROM flutter-android-install AS flutter-android-build
ARG BUILD_CONFIGURATION="release"
WORKDIR /src
COPY . .
RUN flutter build apk --$BUILD_CONFIGURATION

FROM scratch AS flutter-android
COPY --from=flutter-android-build /src/build/app/outputs/flutter-apk/ /
