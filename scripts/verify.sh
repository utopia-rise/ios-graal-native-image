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
grep -q 'actions/checkout@v7.0.1' "$workflow"
grep -q 'graalvm/setup-graalvm@v1' "$workflow"
grep -q 'actions/upload-artifact@v7.0.1' "$workflow"
if grep -Eq 'gh release|create-release|action-gh-release' "$workflow"; then
  echo "The workflow must not publish a GitHub release." >&2
  exit 1
fi
