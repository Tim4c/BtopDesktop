# Development and building

[Documentation index](index.md) · [Project home](../README.md)

Run the commands below from the repository root. A source checkout must be assembled into
an application bundle before normal use: the executable expects bundled btop, themes,
and SwiftTerm resources.

## Toolchain, dependencies, and application assembly

The pinned runtime requires Apple Silicon and macOS 27 or later. Building requires Xcode with its
command-line tools and Swift 6. The dependencies are installed locally after cloning:

```sh
scripts/install-vendor.zsh
scripts/build-app.zsh
open BtopDesktop.app
```

SwiftPM resolves **SwiftTerm 1.19.0** and **SwiftLintPlugins 0.65.1** into `.build/`.
`Package.resolved` records the exact revisions. The vendor installer downloads **btop 1.4.7** from
an immutable Homebrew bottle URL recorded in `vendor-manifest.tsv`, checks its SHA-256, and extracts
its executable, themes and licenses into `Vendor/`. It never runs Homebrew or archive install hooks.
Neither downloaded sources nor binaries are committed or installed into the developer's PATH.

```sh
scripts/install-vendor.zsh --verify
scripts/install-vendor.zsh --force
```

Verification checks installed file hashes. Forced installation reuses verified cached downloads.
Installation is locked and assembled in isolation before replacing the previous runtime. The
installer rejects unexpected non-system dynamic dependencies rather than creating a broken bundle.

Quit the app from its menu bar before rebuilding. The build refuses to replace a running bundle.

The build script compiles the application, assembles `BtopDesktop.app`, copies btop and SwiftTerm's
resource bundle and licenses, then signs it. End users need no dependency installer: the assembled
application contains its runtime.

For a stable local signing identity, run once:

```sh
scripts/setup-local-signing.zsh
```

This creates a dedicated self-signed code-signing certificate and private key in your default user
keychain, with user-level trust restricted to code signing. macOS may request confirmation.
Temporary key files are deleted when the script exits. No certificate or private key is committed.
The build automatically uses `BtopDesktop Local Development` when available, otherwise falls back
to ad hoc signing. Override the signing identity with `BTOP_CODESIGN_IDENTITY` when needed.
After switching identities, authorize Accessibility once more and retain the same certificate
and bundle identifier for subsequent builds. Moving the app or changing its signing identity
may require renewed authorization. A local certificate does not make the app suitable for
notarized distribution; use Developer ID for that.

The standard SwiftPM build system compiles SwiftTerm's declared Metal shader resource, even though
this application uses its CoreGraphics renderer. Install Apple's Metal Toolchain component once
for the selected Xcode installation before building:

```sh
xcodebuild -downloadComponent MetalToolchain
```

This is a developer tool, not an application dependency, and is not copied into the bundle.
The build script checks its availability before compiling. See Apple's
[additional Xcode components documentation](https://developer.apple.com/documentation/xcode/downloading-and-installing-additional-xcode-components).

## Common commands

| Command | Purpose |
| --- | --- |
| `scripts/install-vendor.zsh` | Install the pinned btop executable, themes, and licenses |
| `scripts/install-vendor.zsh --verify` | Check the installed vendor files against their hashes |
| `scripts/install-vendor.zsh --force` | Reinstall from verified cached downloads when possible |
| `scripts/build-app.zsh` | Build in release mode, assemble the app, and sign it |
| `swift build` | Compile the Swift package without assembling a distributable app |
| `scripts/lint.zsh` | Run strict SwiftLint through SwiftPM |
| `scripts/lint.zsh --fix` | Apply supported formatting fixes, then run strict lint |
| `swift test` | Run the package tests |
| `codesign --verify --deep --strict BtopDesktop.app` | Verify the assembled signature |

The build script requires the running app to be closed before replacing the bundle.
See [Testing](testing.md) for automated coverage and manual checks.

## Project layout

| Path | Purpose |
| --- | --- |
| `Sources/BtopDesktop/App/` | Application lifecycle, preferences, panel and desktop presentation |
| `Sources/BtopDesktop/UI/` | Native terminal view, loading presentation and Settings |
| `Sources/BtopDesktop/Infrastructure/` | PTY transport, runtime, btop configuration, desktop icons and overview monitoring |
| `Sources/NativePTYSupport/` | C PTY creation and child signal initialization |
| `Tests/BtopDesktopTests/` | Product behavior and terminal integration tests |
| `scripts/` | Local dependency installation, app assembly and lint |
| `vendor-manifest.tsv` | Locked btop archive and checksum |
| `Vendor/` | Ignored installed executable, themes and licenses |
| `.vendor-cache/` | Ignored downloaded archives |
| `.build/` | Ignored SwiftPM checkouts and build outputs |

## Updating dependencies

Update the exact Swift package version in `Package.swift`, resolve it, and review the resulting
`Package.resolved`. For btop, update the version, immutable archive URL and SHA-256 in
`vendor-manifest.tsv`, then force installation. Rebuild, lint and run the tests before distribution.
The btop bottle must remain compatible with the supported OS and architecture and depend only on
macOS system libraries.

Review [Dependencies and distribution](dependencies.md) before sharing an assembled bundle.

## Making a change

Read [Architecture](architecture.md) to locate the owner of the behavior. For overview state detection and
blur, also read [Overview transitions](overview-transitions.md). Keep presentation preferences
separate from btop configuration; preserve the shutdown and focus rules documented there.

Run the relevant existing tests and add a regression test when fixing behavior. Run strict
lint, the broader test suite, and manual checks appropriate to the change before distribution.
When settings, defaults, storage paths, runtime versions, or compatibility change, update
the matching documentation page and the quick-start requirements if necessary.

The optional `graphify-out/` directory contains a generated code graph. It is a navigation aid,
not the source of truth; regenerate or update it after code/documentation changes before
relying on it for current behavior.

## Menu bar icon

The custom menu bar image is `Resources/Assets.xcassets/MenuIcon.imageset/MenuIcon.svg`.
Edit this SVG to change the design. Its image set preserves vector data and uses template
rendering so macOS supplies the appropriate monochrome appearance. `AppDelegate` loads
`MenuIcon` at 18 × 18 points, with the chart SF Symbol as a fallback for package-only runs
that do not contain the assembled app's assets.

The build script compiles the catalog with Xcode's `actool` before replacing the existing
app bundle, then copies `Assets.car` into `Contents/Resources` before signing. No PDF export
or change to `Package.swift` is required. Rebuild with `scripts/build-app.zsh` after editing
the icon. The Finder application icon remains the separate `Resources/AppIcon.icns` file.
