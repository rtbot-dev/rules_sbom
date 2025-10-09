# Windows Testing via Parallels CLI

This guide explains how to exercise the GitHub CI workflow steps for Windows from a macOS host by driving a Parallels Desktop VM over the CLI. It matches the flags used in `.github/workflows/ci.yml` so you can verify fixes locally before pushing.

## Prerequisites

- Parallels Desktop 18+ installed with the [`prlctl`](https://kb.parallels.com/en/117342) command-line interface available on the host.
- A Windows 11 VM configured in Parallels (the examples below assume it is named `Windows 11`). Adjust the VM name if yours differs.
- Parallels Shared Folders enabled so the macOS workspace (for example, `~/Documents/me/rules_sbom`) is visible inside Windows as `\\Mac\Home`.

Run the following from macOS to confirm the VM name and power state:

```bash
prlctl list
```

If the VM is stopped, start it before proceeding:

```bash
prlctl start "Windows 11"
```

## Basic connectivity checks

Verify you can execute commands in the guest:

```bash
prlctl exec "Windows 11" cmd.exe /c "whoami"
```

Confirm the Parallels shared folder is mapped (usually drive `Z:`):

```bash
prlctl exec "Windows 11" cmd.exe /c "net use"
```

List the repository directory from Windows to ensure the path is correct:

```bash
prlctl exec "Windows 11" cmd.exe /c ^
  "dir Z:\Documents\me\rules_sbom"
```

## Install Bazelisk for Windows

The workflow relies on Bazel 7.x downloaded on demand via Bazelisk. Fetch the Bazelisk stub directly into the repository (or a temporary directory) from the macOS host:

```bash
prlctl exec "Windows 11" powershell -Command ^
  "Invoke-WebRequest -Uri https://github.com/bazelbuild/bazelisk/releases/download/v1.20.0/bazelisk-windows-amd64.exe -OutFile Z:\Documents\me\rules_sbom\bazel.exe"
```

This produces `bazel.exe` in the workspace, which Bazelisk will upgrade to the exact Bazel version requested by the repo.

## Set Windows-specific Bazel environment

The CI workflow configures two environment variables before running Bazel on Windows:

- `BAZEL_SH=C:\Windows\System32\cmd.exe`
- `MSYS2_ARG_CONV_EXCL=//`

When invoking Bazel through `prlctl`, prepend the same variables. The snippet below also ensures the working directory is the shared folder:

```bash
prlctl exec "Windows 11" cmd.exe /c ^
  "cd /d Z:\Documents\me\rules_sbom ^
   && set BAZEL_SH=C:\Windows\System32\cmd.exe ^
   && set MSYS2_ARG_CONV_EXCL=// ^
   && bazel.exe --version"
```

The first invocation may download the platform-appropriate Bazel binary into the Bazelisk cache; subsequent runs reuse it.

## Run the CI-equivalent commands

### 1. Tests

```bash
prlctl exec "Windows 11" cmd.exe /c ^
  "cd /d Z:\Documents\me\rules_sbom ^
   && set BAZEL_SH=C:\Windows\System32\cmd.exe ^
   && set MSYS2_ARG_CONV_EXCL=// ^
   && bazel.exe test --nocache_test_results //tests:inputs_manifest"
```

### 2. Example SBOM builds

```bash
prlctl exec "Windows 11" cmd.exe /c ^
  "cd /d Z:\Documents\me\rules_sbom ^
   && set BAZEL_SH=C:\Windows\System32\cmd.exe ^
   && set MSYS2_ARG_CONV_EXCL=// ^
   && bazel.exe build --verbose_failures ^
        //examples/node:hello_sbom ^
        //examples/go:hello_sbom ^
        //examples/python:hello_sbom ^
        //examples/node_complex:express_sbom ^
        //examples/go_complex:cobra_sbom ^
        //examples/python_complex:httpx_sbom"
```

Both commands should exit with `0`. If Bazel outputs nothing, use `--test_output=errors` (tests) or `--profile` (build) to collect additional diagnostics.

## Optional: Use a dedicated Windows workspace

Some teams prefer copying the repo into a Windows-owned directory to avoid symlink or permission quirks. You can mirror the repository into `C:\bazelws` and then run the same commands in that directory:

```bash
prlctl exec "Windows 11" cmd.exe /c ^
  "robocopy Z:\Documents\me\rules_sbom C:\bazelws /MIR"

prlctl exec "Windows 11" cmd.exe /c ^
  "cd /d C:\bazelws ^
   && set BAZEL_SH=C:\Windows\System32\cmd.exe ^
   && set MSYS2_ARG_CONV_EXCL=// ^
   && bazel.exe test --nocache_test_results //tests:inputs_manifest"
```

Remember to delete the mirror when you no longer need it to recover disk space:

```bash
prlctl exec "Windows 11" cmd.exe /c "rmdir /s /q C:\bazelws"
```

## Cleanup

- Remove the downloaded Bazelisk stub if you do not want it committed:

  ```bash
  rm bazel.exe
  ```

- Clear Bazelisk caches in the guest if space is tight:

  ```bash
  prlctl exec "Windows 11" cmd.exe /c ^
    "rmdir /s /q %LOCALAPPDATA%\bazelisk"
  ```

## Troubleshooting tips

- **`bazel.exe` not found**: Ensure the download step succeeded and `bazel.exe` lives in the directory you `cd` into.
- **`%LocalAppData% is not defined`**: Set `USERPROFILE` and `LOCALAPPDATA` explicitly (as shown above) when running under service accounts or custom users without a profile.
- **Permission errors writing to `_bazel` directories**: Use `--output_user_root=C:/some/path` that your user controls, or mirror the repo into a Windows-owned directory (`C:\bazelws`).
- **Sandbox network failures**: Parallels shared networking can block outbound traffic. Verify the VM has internet access (`prlctl exec ... powershell -Command "Test-NetConnection github.com"`).

Following these steps ensures the Windows workflow matches the GitHub Actions configuration and exercises the same Bazel flags as the official CI matrix.
