#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../toolchain.env
source "$root_dir/toolchain.env"

test "$JDK_VERSION" = "25"
test "$DEFAULT_RELEASE_VERSION" = "25.0.4-ios.1"
test -f "$root_dir/labs-openjdk/ios-jdk.patch"
test -f "$root_dir/cap-cache-generator/build.gradle.kts"
workflow="$root_dir/.github/workflows/build-release.yml"
test -f "$workflow"
git -C "$root_dir/labs-openjdk/labs-openjdk-25" apply --check ../ios-jdk.patch

for name in libjava-release.a libjvm-release.a; do
  grep -q "$name" "$root_dir/scripts/assemble-release.sh"
done

grep -q 'cap-cache-files.txt' "$root_dir/scripts/assemble-release.sh"
grep -q 'manifest.json' "$root_dir/scripts/assemble-release.sh"
grep -q 'workflow_dispatch:' "$workflow"
grep -q 'runs-on: macos-26' "$workflow"
grep -q 'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1' "$workflow"
grep -q 'graalvm/setup-graalvm@5298d94fb55a4f185c602eeac5de1b553882abe2' "$workflow"
grep -q 'actions/upload-artifact@043fb46d1a93c77aae656e7c1c64a875d1fc6a0a' "$workflow"
if grep -Eq 'gh release|create-release|action-gh-release' "$workflow"; then
  echo "The workflow must not publish a GitHub release." >&2
  exit 1
fi
