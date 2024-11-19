# LINUX
ARG BASE_FLUTTER_RUST_IMAGE
FROM $BASE_FLUTTER_RUST_IMAGE AS flutter-linux-install
RUN apt-get install \
      clang cmake git \
      ninja-build pkg-config \
      libgtk-3-dev liblzma-dev \
      libstdc++-12-dev
RUN flutter precache --linux
RUN flutter doctor --verbose

FROM flutter-linux-install AS flutter-linux-build
ARG BUILD_CONFIGURATION="release"
RUN flutter build linux --$BUILD_CONFIGURATION

FROM scratch AS flutter-linux
COPY --from=flutter-linux-build /build/linux/x64/release/bundle/ /
