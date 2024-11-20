set windows-powershell := true

RUST_VERSION := "1.82.0"
FLUTTER_VERSION := "3.24.5"

COMMIT_HASH := `git rev-parse --short HEAD`
BUILD_BASE_TAG := "flutter-rust:" + FLUTTER_VERSION + "-rust" + RUST_VERSION
OUT_DIR := "build/docker/"
OUT_DIR_LINUX := OUT_DIR + "linux/"
OUT_DIR_ANDROID := OUT_DIR + "android/"
BUILD_CONFIGURATION := "release"
ANDROID_ARCH := "android-arm,android-arm64,android-x64"

build-base:
  docker build \
    --target flutter-rust \
    --build-arg RUST_VERSION={{RUST_VERSION}} \
    --build-arg FLUTTER_VERSION={{FLUTTER_VERSION}} \
    -t {{BUILD_BASE_TAG}} \
    -f Dockerfile \
    .

build-linux: build-base
  docker build \
    --target flutter-linux \
    --build-arg BUILD_BASE_TAG={{BUILD_BASE_TAG}} \
    --build-arg BUILD_CONFIGURATION={{BUILD_CONFIGURATION}} \
    -t flutter-linux:{{FLUTTER_VERSION}}-{{COMMIT_HASH}} \
    -f linux.Dockerfile \
    --output {{OUT_DIR_LINUX}} \
    .

build-android: build-base
  docker build \
    --target flutter-android \
    --build-arg BUILD_BASE_TAG={{BUILD_BASE_TAG}} \
    --build-arg BUILD_CONFIGURATION={{BUILD_CONFIGURATION}} \
    --build-arg TARGET_ARCH={{ANDROID_ARCH}} \
    -t flutter-linux:{{FLUTTER_VERSION}}-{{COMMIT_HASH}} \
    -f android.Dockerfile \
    --output {{OUT_DIR_ANDROID}} \
    .
  echo "Built APK are placed in: {{OUT_DIR_ANDROID}}"

log-android:
  adb logcat --pid={{`adb shell pidof -s com.example.frb_base`}}
