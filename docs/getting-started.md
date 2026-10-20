# Getting started

[Documentation index](index.md) · [Project home](../README.md)

This guide is for someone running an assembled Btop Desktop application. To create the
application from source, follow [Development and building](development.md).

## Requirements and distribution

The current bundle requires **macOS 27 or later on Apple Silicon (ARM64)**. The embedded btop binary also imposes this requirement; changing only the Swift manifest or plist does not add
support for earlier macOS versions.

The application is built and signed locally. A dedicated local certificate can keep its signing
identity stable across builds; this is not a Developer ID signature or notarization. The project
currently provides no notarized distribution, installer, or automatic updates.

## First launch

1. Open `BtopDesktop.app` from the project folder or after copying it to Applications.
2. Find the chart icon in the menu bar. The application has no Dock icon.
3. Open **Settings** to adjust its presentation.
4. Enable **Enable interactive mode** to interact with btop.
5. Return to Wallpaper mode for passive viewing.

On the first launch without saved preferences, the panel is centered, occupies 75% of the width and
55% of the height of the screen’s available area, and starts in Wallpaper mode. At launch, the
application selects the screen containing the pointer, falling back to the main screen.

Settings labels are currently in English; some error messages are in French.

## Accessibility access

Grant access in **System Settings → Privacy & Security → Accessibility → Btop Desktop**.
The first click in the interactive terminal requests this permission. After granting access,
click the terminal again. Access enables exclusive handling of plain Escape while btop has
focus and detection of Mission Control/App Exposé for blur transitions.

Without access, the terminal still accepts normal keyboard input after a click, but plain
Escape cannot be reserved exclusively for btop and overview detection is unavailable.
If access stops working after moving or rebuilding the app, check the authorized application
and its signing identity; see [Troubleshooting](troubleshooting.md).

## A first session

1. Open Settings from the menu bar and choose a position, size, and appearance.
2. Enable **Enable interactive mode**, then click inside the panel to give btop focus.
3. Use btop's menus to change monitoring options; use Settings for panel presentation and themes.
4. Disable interactive mode to let clicks pass through to the desktop.
5. Choose **Quit** from the menu bar to let btop save its configuration and close.

Continue with the [User guide](user-guide.md) and [Configuration and themes](configuration.md).
