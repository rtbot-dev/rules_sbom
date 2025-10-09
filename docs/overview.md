# Overview

`rules_sbom` delivers Bazel-native rules that wrap external SBOM generation tooling.

Key goals:
- Simple integration for multiple languages via Bazel targets.
- Toolchain-driven selection of SBOM backends.
- Extensible wrapper architecture that can incorporate Syft, cdxgen, or other CLIs.

The `examples/` tree contains both minimal and transitive-dependency scenarios across Node.js, Python, and Go to highlight how lockfiles influence the generated SBOMs.

The initial focus is on CycloneDX JSON output, with SPDX JSON planned shortly thereafter.
