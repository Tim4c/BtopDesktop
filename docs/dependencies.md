# Dependencies and distribution

[Documentation index](index.md) · [Project home](../README.md)

## Pinned components

| Component        | Version/source of truth                                    | Role                                               |
| ---------------- | ---------------------------------------------------------- | -------------------------------------------------- |
| btop             | 1.4.7; `vendor-manifest.tsv` locks archive URL and SHA-256 | Monitoring process, themes, and terminal interface |
| SwiftTerm        | 1.19.0; `Package.swift` and `Package.resolved`             | Embedded native terminal                           |
| SwiftLintPlugins | 0.65.1; `Package.swift` and `Package.resolved`             | Development/build lint tooling                     |

The current package and bundle target macOS 27 or later on ARM64. The downloaded btop binary also
constrains compatibility; changing the Swift deployment target alone is insufficient. Check the
package, `Info.plist`, vendor manifest, and actual binary together when changing support.

## Vendor provenance

`scripts/install-vendor.zsh` downloads the locked immutable Homebrew bottle archive directly,
verifies SHA-256, and extracts only the runtime payload into ignored `Vendor/`. It does not run
Homebrew or archive install hooks, and does not install the executable into PATH. The ignored
`.vendor-cache/` holds cached archives. Installation is locked, prepared in isolation, and validates
non-system dynamic dependencies before replacing the old runtime.

Use [Development](development.md#updating-dependencies) for the update procedure.

## Application bundle

```text
BtopDesktop.app/Contents/
  Info.plist
  MacOS/BtopDesktop
  Resources/
    bin/btop
    themes/
    licenses/
    SwiftTerm_*.bundle
```

The assembly script copies SwiftTerm's generated resources and licenses along with btop. The built
app is self-contained for end users: they do not need Homebrew, SwiftPM, SwiftLint, Xcode, or the
vendor installer to run it on the supported OS/architecture.

## Signing and current release status

The build uses `BtopDesktop Local Development` when that local signing identity is available,
otherwise ad hoc signing. `BTOP_CODESIGN_IDENTITY` overrides the choice. The local certificate
workflow is documented in [Development](development.md); it stabilizes local identity but does not
provide Developer ID distribution or notarization.

The project currently provides no notarized release, installer, or automatic update mechanism. The
[community prerelease workflow](releases.md) prepares an ad hoc signed ZIP and a matching Homebrew
cask as a draft for review. Before sharing a bundle, verify its signature, test it on the intended
target environment, and review its included license/provenance material. Developer ID signing and
notarization require a separate distribution workflow.

## Embedded licenses

- **btop 1.4.7**: Apache-2.0; its license and pinned archive provenance accompany the executable.
- **SwiftTerm**: MIT; its license is copied into the application resources.
- **SwiftLintPlugins**: development tooling, managed by SwiftPM and not bundled in the app.

The assembled bundle includes third-party notices in `Contents/Resources/licenses/`. Public
redistribution must satisfy the included licenses. For btop, include the Apache-2.0 license,
preserve applicable notices, include any required upstream NOTICE material, and identify modified
files if distributing changes. Apache-2.0 does not require publishing corresponding source merely
because a binary is distributed.

Btop Desktop's original source code and documentation are licensed under the
[MIT License](../LICENSE). This does not change the licenses of third-party components. Refer to
each dependency's supplied license text and provenance when preparing a release.
