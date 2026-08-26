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
  --disable-warnings-as-errors \
  --with-version-opt="$JVMCI_VERSION" \
  --with-version-pre= \
  --with-vendor-name="GraalVM Community" \
  --with-vendor-url=https://www.graalvm.org/ \
  --with-vendor-bug-url=https://github.com/oracle/graal/issues \
  --with-vendor-vm-bug-url=https://github.com/oracle/graal/issues
make CONF_NAME=labsjdk graal-builder-image
popd >/dev/null

# ProcessImpl_md.c checks VERSION_STRING against the jspawnhelper it spawns,
# so libjava has to be compiled with the same value the JDK build used.
jdk_version_string="$(sed -n 's/^[[:space:]]*VERSION_STRING[[:space:]]*:*=[[:space:]]*//p' \
  "$jdk_source/build/labsjdk/spec.gmk" | head -1)"
if [ -z "$jdk_version_string" ]; then
  echo "Could not read VERSION_STRING from $jdk_source/build/labsjdk/spec.gmk." >&2
  exit 1
fi

# Release builds drop debug info: DWARF records the build machine's absolute
# source paths, and the libjava single-object prelink turns every input object
# into an N_OSO debug-map entry pointing at a path that cannot exist on a
# consumer's machine, so their linker warns about each one. The debug variants
# keep it, since that is the point of shipping them.
build_archive() {
  local project="$1"
  local target="$2"
  local configuration="$3"
  local debug_symbols="$4"
  shift 4
  xcodebuild \
    -project "$project" \
    -target "$target" \
    -configuration "$configuration" \
    -sdk iphoneos \
    ARCHS=arm64 \
    IPHONEOS_DEPLOYMENT_TARGET="$IOS_MIN_VERSION" \
    ONLY_ACTIVE_ARCH=NO \
    GCC_GENERATE_DEBUGGING_SYMBOLS="$debug_symbols" \
    "$@" \
    build
}

openjdk_project="$root_dir/labs-openjdk/svm.openjdk.xcodeproj"
graal_project="$root_dir/svm/svm.graal.xcodeproj"

build_archive "$openjdk_project" libjava Release-ios NO "JDK_VERSION_STRING=$jdk_version_string"
build_archive "$graal_project" libjvm Release-ios NO
build_archive "$openjdk_project" libjava Debug-ios YES "JDK_VERSION_STRING=$jdk_version_string"
build_archive "$graal_project" libjvm Debug-ios YES

pushd "$root_dir/cap-cache-generator" >/dev/null
./gradlew generateCapCache -PgraalvmHome="$GRAALVM_HOME"
popd >/dev/null

"$root_dir/scripts/assemble-release.sh"
