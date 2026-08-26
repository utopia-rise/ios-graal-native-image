# iOS Graal JDK 25

This repository builds the unofficial iOS runtime required to compile JVM code with
GraalVM Native Image for iOS/arm64. It combines the previously separate iOS JDK
and CAP-cache projects into one versioned release unit.

## Contents

- `labs-openjdk/labs-openjdk-25` is the JDK 25.0 JVMCI source submodule.
- `svm/graal` is the matching GraalVM 25.0 source submodule.
- `labs-openjdk/ios-jdk.patch` contains the iOS OpenJDK changes and applies to
  the pinned JDK source revision.
- `labs-openjdk/svm.openjdk.xcodeproj` builds `libjava.a`.
- `svm/svm.graal.xcodeproj` builds `libjvm.a`.
- `cap-cache-generator` produces the iOS CAP cache using the same GraalVM.

The project intentionally produces static archives and CAP cache data only. It
does not claim official GraalVM iOS support.

## Build a release bundle

Build on macOS with Xcode and a GraalVM 25.0.4 JDK that includes
`native-image`:

```bash
git clone --recurse-submodules <repository-url>
cd ios-graal-jdk-25
export GRAALVM_HOME=/path/to/graalvm-jdk-25
./scripts/build-release.sh
```

The final assets are written to `dist/`:

```text
libjava-release.a
libjvm-release.a
*.cap
cap-cache-files.txt
SHA256SUMS
manifest.json
```

Upload every file in `dist/` to one GitHub release. The Gradle plugin should
download `libjava-release.a`, `libjvm-release.a`, `cap-cache-files.txt`, and
the CAP files named by that list from that single release tag.

## GitHub Actions

Run **Build iOS Graal JDK 25** manually from the Actions tab. It builds the
same `dist/` directory and uploads it as a workflow artifact named
`ios-graal-jdk-<release version>`. The workflow deliberately does not create a
GitHub release or publish assets.

Before changing either source submodule, update `toolchain.env`, port
`labs-openjdk/ios-jdk.patch`, and validate it with:

```bash
./scripts/verify.sh
```
