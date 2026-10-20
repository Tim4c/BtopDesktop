# Preparing a community prerelease

[Documentation index](index.md) · [Project home](../README.md)

Releases target Apple Silicon and macOS 27 or later. They are signed ad hoc and are not notarized by
Apple. No Apple Developer subscription or signing secret is needed.

## Prepare locally

Quit the app, then run:

```sh
scripts/build-app.zsh
scripts/lint.zsh
swift test
scripts/package-release.zsh
```

The package script copies the assembled app into a temporary directory, signs the copy ad hoc, and
verifies it. The local development bundle retains its existing signing identity. The build includes
the project, btop, and SwiftTerm licenses before signing.

For version `0.2.0`, the outputs are in ignored `dist/v0.2.0/`:

- `BtopDesktop-0.2.0-macos-arm64.zip`: installable application bundle.
- `SHA256SUMS`: checksum for that exact ZIP.
- `btop-desktop.rb`: Homebrew cask containing the matching version, URL, and checksum.
- `RELEASE_NOTES.md`: installation instructions and testing limitations.

The script refuses to overwrite an existing version directory. Move that directory aside before
regenerating an unpublished candidate. Never replace the assets of a published version; increment
`CFBundleShortVersionString` and `CFBundleVersion` in `Info.plist` instead.

## Create the draft on GitHub

Commit and push the release preparation first. Then create and push a tag matching
`CFBundleShortVersionString` exactly:

```sh
git tag -a v0.2.0 -m "Btop Desktop 0.2.0 community prerelease"
git push origin v0.2.0
```

The [release workflow](../.github/workflows/release.yml) builds, lints, tests, and packages the
tagged code, then creates a **draft prerelease** with the ZIP, checksum, and cask attached. The tag
must match the version in `Info.plist`. The workflow never publishes the draft or changes a separate
tap repository automatically.

Download the ZIP and checksum from the draft, then verify in their download directory:

```sh
shasum -a 256 --check SHA256SUMS
```

Quit the development app before opening the downloaded build. Check first launch, menu bar,
Accessibility permissions, themes, quit, and replacing a previous installation. A test on the
development Mac cannot establish first-launch behavior on a clean Mac. Keep the initial release
experimental and request community feedback. Publish the draft after reviewing the assets and notes.

## Publish the personal Homebrew tap

Create a public repository named `Tim4c/homebrew-tap`. Add the **cask attached to the published
release** as `Casks/btop-desktop.rb`. Do not regenerate the ZIP locally and use its checksum: ad hoc
signatures and archive metadata can produce different bytes.

Add a README to the tap explaining the experimental status, platform requirements, and:

```sh
brew install --cask Tim4c/tap/btop-desktop
```

After adding the cask to the tap, validate it with Homebrew:

```sh
brew tap Tim4c/tap
brew style --cask Tim4c/tap/btop-desktop
brew audit --cask Tim4c/tap/btop-desktop
```

Test installation from the published URL, including the checksum and launch behavior. Homebrew does
not bypass Gatekeeper or make the app notarized. The cask does not delete user preferences on
uninstall and does not alter global security settings. Update the cask's version and checksum from
each new release; users can then run `brew upgrade --cask btop-desktop`.
