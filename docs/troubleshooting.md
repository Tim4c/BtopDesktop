# Troubleshooting and limitations

[Documentation index](index.md) · [Project home](../README.md)

## Supported scope

The app displays one desktop panel, initially on the screen containing the pointer. It does not
provide monitoring history, alerts, remote monitoring, automatic updates or a notarized installer.
The menu bar interface remains available while the panel is inactive.

If the panel disappears, check whether the menu bar icon remains and inspect
`~/Library/BtopDesktop/native-terminal.log`. A normal btop exit ends the application. If interactive
mode receives no keyboard input, click inside btop first. Closing Settings deliberately clears panel
focus. If dependencies fail verification, rerun the vendor installer; if a download fails, check
network access to GitHub and the GitHub Container Registry.

## Common symptoms

| Symptom | Checks and next action |
| --- | --- |
| App cannot start or reports a missing runtime tool | Use the assembled `.app`; rebuild it if `Contents/Resources/bin/btop` or themes are missing |
| Panel disappears and menu bar item also vanishes | A normal btop exit closes the app; inspect the terminal log for startup/shutdown messages |
| Keyboard or scrolling does nothing | Enable interactive mode and explicitly click inside the terminal; Settings clears focus |
| Escape reaches Show Desktop or other handlers | Grant Accessibility permission and click the terminal again; verify the currently running app's authorization |
| No blur in Mission Control/App Exposé | Check Accessibility access; detection depends on observed Dock identifiers |
| Blur appears or disappears slightly late | Detection polls every 150 ms; Accessibility reads and main-thread scheduling can add delay. The blur itself has no animation |
| Theme import fails | Choose one regular UTF-8 `.theme` file with recognized valid color definitions; its destination path must contain no double quotes or line breaks |
| Theme selection is refused | Enable btop's Save config on exit; a forced/unsuccessful stop prevents a theme update |
| Colors look gray after selecting a theme | Theme preview ends when Settings loses focus; inspect active/inactive grayscale settings |
| Desktop-icon change fails | The app attempts to restore the previous Finder preference. If restoration also fails, inspect the reported error and retry once Finder is running |
| Desktop icons remain hidden after quit | The Finder setting persists globally; disable Hide desktop icons in the app |
| Build asks for Metal Toolchain | Install the component for the selected Xcode, as described in Development |
| Dependency verification fails | Rerun `scripts/install-vendor.zsh --verify`, then reinstall with `--force` if needed |
| Build refuses to replace the app | Quit Btop Desktop from its menu bar, then rerun the build script |
| Accessibility stopped working after a rebuild/move | Confirm the app entry in System Settings; retain a stable signing identity and bundle identifier |

## Logs and environment

The PTY lifecycle log is `~/Library/BtopDesktop/native-terminal.log`. It records native btop
startup and shutdown; it is not a full terminal transcript or frame-performance trace.
btop runtime state/log data belongs to `~/Library/Application Support/BtopDesktop/state/`.
See [Configuration](configuration.md) for preferences, configuration, and imported themes.

For build failures, keep the command output and check the selected Xcode with `xcode-select -p`.
Vendor downloads need network access to the archive hosts specified in `vendor-manifest.tsv`.
SwiftPM dependencies need access to their repositories. Local signing may prompt for keychain
access; see [Development](development.md#toolchain-dependencies-and-application-assembly).

## Blur limitations

Overview detection depends on Accessibility and observed Dock identifiers. Mission Control and
App Exposé use a fixed blur; Desktop and Show Desktop remove it without animation. There is no
private gesture capture or frame clock. Polling and Accessibility reads can add a short delay,
and a brief or cancelled overview may finish between polls. Without Accessibility access,
overview detection is unavailable and the panel stays sharp.

See [Overview state and fixed blur](overview-transitions.md#detection-latency-and-manual-validation)
for manual checks on the supported macOS version.

## Before reporting a problem

Provide macOS version, Apple Silicon model, app build, display/refresh-rate details,
Accessibility status, and exact reproduction steps. Include whether the app was rebuilt
after the latest source change. Remove personal information from logs before sharing them.
Developers should attach relevant test results, including skipped integration/display tests.
