Experimental community prerelease for **Apple Silicon and macOS 27 or later**.

This application is signed ad hoc, **not notarized by Apple**. Initial validation is on the
maintainer's Mac and GitHub Actions; behavior on other Macs needs community feedback.

## Install the ZIP

1. Download `BtopDesktop-<version>-macos-arm64.zip` and `SHA256SUMS` from this release.
2. In their download directory, run `shasum -a 256 --check SHA256SUMS`.
3. Unzip and move `BtopDesktop.app` into Applications, then open it.
4. If macOS blocks the app, review the message in **System Settings → Privacy & Security**. Use
   **Open Anyway** only if you trust this download and macOS offers that option. Do not disable
   Gatekeeper globally. Managed Macs may prevent overrides. See
   [Apple's opening instructions](https://support.apple.com/102445).
5. Find the chart icon in the menu bar; the app has no Dock icon. Accessibility access enables
   focused Escape handling and Mission Control/App Exposé detection.

Quit the app before replacing or upgrading it. Updates may require granting Accessibility permission
again. No automatic updater is included.

## Homebrew

Once this release's cask is published in `Tim4c/homebrew-tap`:

```sh
brew install --cask Tim4c/tap/btop-desktop
```

Homebrew does not notarize the app or bypass macOS security checks.

The `btop-desktop.rb` attachment is the cask definition for tap maintainers, not an installer to run
directly. The ZIP includes the project MIT license and the btop/SwiftTerm licenses under
`BtopDesktop.app/Contents/Resources/licenses/`.

Please report your macOS version, Mac model, reproduction steps, and relevant logs when opening an
issue. Remove private information from screenshots and logs.
