# Toolchains

`rules_sbom` resolves SBOM tooling via Bazel toolchains.

- `//toolchains:sbom_toolchain_type` defines the contract describing the executable, supported formats, and optional wrapper.
- `rules_sbom_register_toolchains()` registers the default Syft-backed toolchain.
- Custom toolchains may wrap alternative binaries by returning `SbomToolchainInfo`.

In the incubation phase, only the Syft toolchain is provided out of the box.
