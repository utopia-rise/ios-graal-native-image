#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
dist_dir="$root_dir/dist"
rm -rf "$dist_dir"
mkdir -p "$dist_dir"

copy_archive() {
  local source_root="$1"
  local source_name="$2"
  local target_name="$3"
  local source
  source="$(find "$source_root" -type f -name "$source_name" -print -quit)"
  if [[ -z "$source" ]]; then
    echo "Could not find $source_name below $source_root." >&2
    exit 1
  fi
  cp "$source" "$dist_dir/$target_name"
}

copy_archive "$root_dir/labs-openjdk/svm.openjdk.xcodeproj/build" libjava.a libjava-release.a
copy_archive "$root_dir/svm/svm.graal.xcodeproj/build" libjvm.a libjvm-release.a

cap_dir="$root_dir/cap-cache-generator/build/cap-cache"
cap_files=(
  AArch64LibCHelperDirectives.cap
  AMD64LibCHelperDirectives.cap
  BuiltinDirectives.cap
  JNIHeaderDirectives.cap
  JNIHeaderDirectivesJDK19OrLater.cap
  JNIHeaderDirectivesJDK20OrLater.cap
  JNIHeaderDirectivesJDK21OrLater.cap
  PosixDirectives.cap
  RISCV64LibCHelperDirectives.cap
)

for cap_file in "${cap_files[@]}"; do
  if [[ ! -f "$cap_dir/$cap_file" ]]; then
    echo "Missing CAP cache file: $cap_file" >&2
    exit 1
  fi
  cp "$cap_dir/$cap_file" "$dist_dir/$cap_file"
done

artifact_names=(libjava-release.a libjvm-release.a "${cap_files[@]}")
artifact_json=""
for artifact_name in "${artifact_names[@]}"; do
  artifact_json+="\"$artifact_name\", "
done
artifact_json="${artifact_json%, }"

(
  cd "$dist_dir"
  shasum -a 256 libjava-release.a libjvm-release.a "${cap_files[@]}" > SHA256SUMS
)

cat > "$dist_dir/manifest.json" <<EOF
{
  "jdkVersion": "25",
  "graalVmVersion": "$(grep '^GRAALVM_VERSION=' "$root_dir/toolchain.env" | cut -d= -f2)",
  "labsOpenJdkCommit": "$(git -C "$root_dir/labs-openjdk/labs-openjdk-25" rev-parse HEAD)",
  "graalCommit": "$(git -C "$root_dir/svm/graal" rev-parse HEAD)",
  "artifacts": [$artifact_json],
  "sha256": "SHA256SUMS"
}
EOF
