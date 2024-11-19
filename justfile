set windows-powershell := true

RUST_VERSION := "1.82.0"
FLUTTER_VERSION := "3.24.5"

build-base:
  docker build --target flutter-rust -t flutter-rust:{{FLUTTER_VERSION}}-rust{{RUST_VERSION}} -f Dockerfile .
