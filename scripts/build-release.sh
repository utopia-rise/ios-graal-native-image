#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../toolchain.env
source "$root_dir/toolchain.env"

: "${RELEASE_VERSION:=$DEFAULT_RELEASE_VERSION}"
if [[ ! "$RELEASE_VERSION" =~ ^[0-9A-Za-z][0-9A-Za-z._-]*$ ]]; then
  echo "RELEASE_VERSION must contain only letters, numbers, dots, underscores, and hyphens." >&2
  exit 1
fi
export RELEASE_VERSION

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "An iOS toolchain release must be built on macOS." >&2
  exit 1
fi

: "${GRAALVM_HOME:=${JAVA_HOME:-}}"
if [[ -z "$GRAALVM_HOME" || ! -x "$GRAALVM_HOME/bin/native-image" ]]; then
  echo "Set GRAALVM_HOME to a GraalVM $JDK_VERSION installation with native-image." >&2
  exit 1
fi

if ! "$GRAALVM_HOME/bin/java" -version 2>&1 | grep -q " $JDK_VERSION"; then
  echo "GRAALVM_HOME must use JDK $JDK_VERSION." >&2
  exit 1
fi

export JAVA_HOME="$GRAALVM_HOME"
export GRAALVM_HOME

cd "$root_dir"
git submodule update --init --recursive --depth 1

jdk_source="$root_dir/labs-openjdk/labs-openjdk-$JDK_VERSION"
git -C "$jdk_source" apply --check ../ios-jdk.patch
git -C "$jdk_source" apply ../ios-jdk.patch

pushd "$jdk_source" >/dev/null
bash ./configure \
  --with-conf-name=labsjdk \
  --with-version-opt="$JVMCI_VERSION" \
  --with-version-pre= \
  --with-vendor-name="GraalVM Community" \
  --with-vendor-url=https://www.graalvm.org/ \
  --with-vendor-bug-url=https://github.com/oracle/graal/issues \
  --with-vendor-vm-bug-url=https://github.com/oracle/graal/issues
make CONF_NAME=labsjdk graal-builder-image
popd >/dev/null

xcodebuild \
  -project "$root_dir/labs-openjdk/svm.openjdk.xcodeproj" \
  -target libjava \
  -configuration Release-ios \
  -sdk iphoneos \
  ARCHS=arm64 \
  IPHONEOS_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
  ONLY_ACTIVE_ARCH=NO \
  build

xcodebuild \
  -project "$root_dir/svm/svm.graal.xcodeproj" \
  -target libjvm \
  -configuration Release-ios \
  -sdk iphoneos \
  ARCHS=arm64 \
  IPHONEOS_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
  ONLY_ACTIVE_ARCH=NO \
  build

pushd "$root_dir/cap-cache-generator" >/dev/null
./gradlew generateCapCache -PgraalvmHome="$GRAALVM_HOME"
popd >/dev/null

"$root_dir/scripts/assemble-release.sh"
