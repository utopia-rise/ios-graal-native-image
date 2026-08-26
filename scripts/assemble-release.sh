#!/usr/bin/env bash
set -euo pipefail

root_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=../toolchain.env
source "$root_dir/toolchain.env"
: "${RELEASE_VERSION:=$DEFAULT_RELEASE_VERSION}"
dist_dir="$root_dir/dist"
bundle_name="ios-graal-$RELEASE_VERSION.zip"
bundle_dir="$dist_dir/bundle"
rm -rf "$dist_dir"
mkdir -p "$bundle_dir/caps"

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
  cp "$source" "$bundle_dir/$target_name"
}

# Both projects set SYMROOT to build/xcode next to the project, and
# CONFIGURATION_BUILD_DIR to <configuration>-<platform> below it. Point at that
# directory rather than the whole tree so the intermediate archive under
# *.build/Objects-normal cannot be picked instead of the finished product.
for configuration in release debug; do
  products="$(tr '[:lower:]' '[:upper:]' <<< "${configuration:0:1}")${configuration:1}-ios-iphoneos"
  copy_archive "$root_dir/labs-openjdk/build/xcode/$products" libjava.a "libjava-$configuration.a"
  copy_archive "$root_dir/svm/build/xcode/$products" libjvm.a "libjvm-$configuration.a"
done
archives=(libjava-release.a libjvm-release.a libjava-debug.a libjvm-debug.a)

# Debug info would embed this machine's absolute paths, which a consumer's
# linker then reports as warnings for files it cannot open. Fail loudly instead
# of shipping them, so the release build cannot regress into leaking paths. The
# debug archives carry debug info by definition, so they are exempt.
for archive in libjava-release.a libjvm-release.a; do
  leaked="$(LC_ALL=C grep -a -o -E '/Users/[A-Za-z0-9._-]+/[^ ]*' "$bundle_dir/$archive" | head -3 || true)"
  if [[ -n "$leaked" ]]; then
    echo "$archive embeds absolute build paths:" >&2
    printf '  %s\n' $leaked >&2
    exit 1
  fi
done

cap_dir="$root_dir/cap-cache-generator/build/cap-cache"
cap_files=()
while IFS= read -r cap_file; do
  cap_files+=("$cap_file")
done < <(find "$cap_dir" -maxdepth 1 -type f -name '[A-Za-z0-9]*.cap' -exec basename {} \; | LC_ALL=C sort)

if (( ${#cap_files[@]} == 0 )); then
  echo "No CAP cache files were generated below $cap_dir." >&2
  exit 1
fi

for cap_file in "${cap_files[@]}"; do
  cp "$cap_dir/$cap_file" "$bundle_dir/caps/$cap_file"
done

printf '%s\n' "${cap_files[@]}" > "$bundle_dir/caps/cap-cache-files.txt"

artifact_names=("${archives[@]}")
for cap_file in "${cap_files[@]}"; do
  artifact_names+=("caps/$cap_file")
done
artifact_json=""
for artifact_name in "${artifact_names[@]}"; do
  artifact_json+="\"$artifact_name\", "
done
artifact_json="${artifact_json%, }"

checksum_targets=("${archives[@]}" caps/cap-cache-files.txt)
for cap_file in "${cap_files[@]}"; do
  checksum_targets+=("caps/$cap_file")
done

(
  cd "$bundle_dir"
  shasum -a 256 "${checksum_targets[@]}" > SHA256SUMS
)

cat > "$bundle_dir/manifest.json" <<EOF
{
  "releaseVersion": "$RELEASE_VERSION",
  "jdkVersion": "25",
  "graalVmVersion": "$(grep '^GRAALVM_VERSION=' "$root_dir/toolchain.env" | cut -d= -f2)",
  "labsOpenJdkCommit": "$(git -C "$root_dir/labs-openjdk/labs-openjdk-25" rev-parse HEAD)",
  "graalCommit": "$(git -C "$root_dir/svm/graal" rev-parse HEAD)",
  "artifacts": [$artifact_json],
  "capCacheIndex": "caps/cap-cache-files.txt",
  "sha256": "SHA256SUMS"
}
EOF

(
  cd "$bundle_dir"
  zip -X -q -r "$dist_dir/$bundle_name" "${archives[@]}" caps SHA256SUMS manifest.json
)
rm -rf "$bundle_dir"
