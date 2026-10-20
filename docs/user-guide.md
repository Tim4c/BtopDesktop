# User guide

[Documentation index](index.md) · [Project home](../README.md)

## Product responsibilities

- Displays the information provided by btop: CPU, memory, disks, network activity, and processes,
  depending on system capabilities and btop configuration.
- Integrates monitoring into the desktop through a transparent panel without a standard window
  frame.
- Provides passive viewing and an interactive mode with mouse, scrolling, and keyboard input.
- Customizes panel size, position, opacity, border colors, rounded corners, and grayscale rendering.
- Uses separate appearances for the focused and unfocused panel.
- Lets you hide or show desktop icons.
- Saves presentation preferences and maintains a separate btop configuration for the application.

Monitoring data, menus, and commands come from btop. Btop Desktop handles desktop integration and
presentation.

## Display modes and focus

| Mode            | Desktop placement          | Interaction                                                                          |
| --------------- | -------------------------- | ------------------------------------------------------------------------------------ |
| **Wallpaper**   | Below Finder desktop icons | Clicks pass through the panel; desktop icons remain usable.                          |
| **Interactive** | Above Finder desktop icons | The panel receives mouse, scrolling, and keyboard input. Clicking it gives it focus. |

Interactive mode does not place the panel above every application window. The panel remains at
desktop window levels.

Enabling interactive mode does not activate the panel. It becomes active only after an explicit
click inside btop, and returns to its inactive state when focus is lost. Opening or closing Settings
clears panel focus; another click is required to activate btop.

While the terminal has explicit click focus, plain Escape is intercepted and delivered directly
to btop to prevent the same key from reaching other event handlers, including Show Desktop.
This requires **System Settings → Privacy & Security → Accessibility → Btop Desktop**.
The first terminal click requests access; after granting it, click the terminal again.
Without access, keyboard input still works, but Escape cannot be reserved exclusively for btop.
Modified Escape shortcuts and input outside the focused terminal retain their usual behavior.

The btop panel remains blurred while Mission Control or App Exposé is open and returns to sharp
rendering when it closes. Detection requires Accessibility access and uses the Dock's observed
`mc` and `appexpose` accessibility identifiers; these are not a dedicated, guaranteed macOS API.
Show Desktop does not activate this blur. Detection works independently of terminal focus and
input method. Both keyboard and trackpad activation use the same fixed blur, applied without
animation once the state is detected. Detection polls every 150 ms, so a short delay is possible.
Accessibility permission is required.

The selected mode persists between launches. **Active mode** appearance applies when the panel has
focus; **Inactive mode** appearance applies when it loses focus, including in interactive mode.

## Presentation settings

Changes take effect immediately and preferences are saved automatically.

### Appearance

The active and inactive states each have their own settings:

| Setting      | Range or options    | Active default | Inactive default |
| ------------ | ------------------- | -------------- | ---------------- |
| Opacity      | 10–100%             | 100%           | 75%              |
| Grayscale    | Enabled or disabled | Disabled       | Enabled          |
| Border       | Visible or hidden   | Visible        | Hidden           |
| Border color | Color picker        | `#89B4FA`      | `#535763`        |

Changing an appearance setting previews that state, even when the panel does not have focus. The
preview ends when the Settings window loses focus or another action restores the current appearance.

### Size and position

- **Width / Height**: 30–100% of the width and height of the screen’s available area.
- **Dimension link**: adjusts the other dimension according to the ratio captured when linking is
  enabled, within the slider limits. The ratio may change when either dimension reaches a limit.
- **Font size**: 10–20 points in whole-point steps, initially 12 points. Changes apply immediately
  and are saved between launches; the terminal grid stays centered as its cell size changes.
- **Border radius**: 0–30 points, initially 10 points.
- **Position**: nine anchors arranged in a three-by-three grid.

Dimensions are saved as proportions rather than pixels. Position and size are recalculated when the
display configuration changes. The terminal remains visible during resizing, and its grid then
adjusts to the new size.

### Desktop icons

**Hide desktop icons** changes Finder’s global `CreateDesktop` setting and restarts Finder to apply
it. This affects the entire desktop and remains in effect after Btop Desktop closes. Disable the
option to show the icons again.

The application reads Finder’s current state at launch, when opening the menu, and when opening
Settings. Commands run in the background; the Settings switch and menu action are disabled
while a change is being applied. If restarting Finder fails, the previous preference is restored,
including removing the key if it was originally absent. An error is shown if either the change
or its restoration fails.

### Restoring defaults

The restore button at the top of Settings resets appearance, font size, dimensions, position, and dimension
linking. It leaves the selected theme and imported themes intact. It also attempts to show desktop icons if they were hidden.

It does not reset interactive mode or btop’s internal configuration.

## Themes, btop controls, and quitting

Drop a UTF-8 `.theme` file onto the theme import area in **Settings → Theme**, or click the area
to choose a file. The area highlights when a single `.theme` file is dragged over it.
The app validates its color definitions and copies it into
`~/Library/Application Support/BtopDesktop/btop/themes/`. Existing imports are replaced only after
confirmation. Choose a bundled or imported theme with the **Select** selector in the same card.
When selected, btop exits cleanly to save its current options, the app records the new theme in
`btop.conf`, and btop restarts in the same desktop panel. A brief loading transition may appear.
Grayscale is temporarily bypassed while previewing a selected theme, so its colors remain visible.
The configured grayscale setting returns when Settings loses focus or closes.
The selector is disabled during the change. A forced shutdown cancels the theme change.
If btop’s **Save config on exit** option is disabled, enable it before selecting a theme in Settings.
Imports and the selected theme survive app updates and Restore Defaults.

In interactive mode, click inside the panel to use btop’s terminal commands and menus. Its themes
are included in the bundle. The app manages theme selection; other btop options remain in btop’s own menus.

To close the application, choose **Quit** from the Btop Desktop menu or quit btop from its
interface. Ending the terminal session closes the application.

During a normal shutdown, Btop Desktop first asks btop to exit cleanly so it can save its
configuration. AppKit defers application termination while asynchronous shutdown completes, keeping
the main thread available. Shutdown waits are bounded; an unresponsive process may be forcibly
stopped.

For theme validation and file locations, see [Configuration and themes](configuration.md).
For problems with focus, rendering, or startup, see [Troubleshooting](troubleshooting.md).
