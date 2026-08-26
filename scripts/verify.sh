#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../toolchain.env
source "$root_dir/toolchain.env"

test "$JDK_VERSION" = "25"
test -f "$root_dir/labs-openjdk/ios-jdk.patch"
test -f "$root_dir/cap-cache-generator/build.gradle.kts"
test -f "$root_dir/.github/workflows/build-release.yml"
git -C "$root_dir/labs-openjdk/labs-openjdk-25" apply --check ../ios-jdk.patch

for name in libjava-release.a libjvm-release.a; do
  grep -q "$name" "$root_dir/scripts/assemble-release.sh"
done
