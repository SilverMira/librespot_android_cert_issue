ARG RUST_VERSION=1.82.0
FROM rust:$RUST_VERSION AS base

FROM base AS flutter-rust
ARG FLUTTER_VERSION=3.24.5
RUN apt-get update
RUN apt-get install -y curl git unzip xz-utils zip libglu1-mesa
RUN mkdir -p /flutter-$FLUTTER_VERSION
RUN curl -sL https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_${FLUTTER_VERSION}-stable.tar.xz | tar xJf - -C /flutter-$FLUTTER_VERSION
ENV FLUTTER_HOME=/flutter-$FLUTTER_VERSION/flutter
ENV PATH="$PATH:$FLUTTER_HOME/bin"
RUN git config --global --add safe.directory $FLUTTER_HOME
RUN flutter doctor --verbose
