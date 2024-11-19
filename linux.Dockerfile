# LINUX
ARG BUILD_BASE_TAG
FROM $BUILD_BASE_TAG AS flutter-linux-install
RUN apt-get update
RUN apt-get install -y \
      clang cmake git \
      ninja-build pkg-config \
      libgtk-3-dev liblzma-dev \
      libstdc++-12-dev
RUN flutter precache --linux
RUN flutter doctor --verbose

FROM flutter-linux-install AS flutter-linux-build
ARG BUILD_CONFIGURATION="release"
WORKDIR /src
COPY . .
RUN flutter build linux --$BUILD_CONFIGURATION

FROM scratch AS flutter-linux
COPY --from=flutter-linux-build /src/build/linux/x64/release/bundle/ /
