# Configuration and themes

[Documentation index](index.md) · [Project home](../README.md)

## Local data

There are two separate sets of settings:

| Data                     | Location or storage                                   | Purpose                                    |
| ------------------------ | ----------------------------------------------------- | ------------------------------------------ |
| Presentation preferences | `UserDefaults`, domain `local.btop.desktop`           | Modes, appearance, dimensions, and anchors |
| Imported themes          | `~/Library/Application Support/BtopDesktop/btop/themes/` | User color themes |
| btop state and log        | `~/Library/Application Support/BtopDesktop/state/` | Isolated btop runtime state |
| btop configuration       | `~/Library/Application Support/BtopDesktop/btop.conf` | Monitor settings and themes                |
| Terminal log             | `~/Library/BtopDesktop/native-terminal.log`                      | PTY startup and shutdown messages    |

If Btop Desktop’s configuration file does not exist, the application imports
`~/.config/btop/btop.conf` when available. Otherwise, it creates an initial file. Subsequent
launches use the separate configuration without synchronizing with the original file.

At each launch, the application enforces these settings for integration with the embedded terminal:

```ini
save_config_on_exit = true
```

`terminal_sync` and `background_update` remain btop preferences and are not overridden by the application.
SwiftTerm supports synchronized output (`terminal_sync = true`).

Quit the application before manually editing `btop.conf` to prevent btop from overwriting those
edits when it exits.

## Theme import and selection

In **Settings → Theme**, drop a single regular `.theme` file onto the import area or click
the area to open the file picker. Imports are copied into the application-specific theme
directory. A duplicate filename requires confirmation before replacement. Importing makes
a theme available; choose it in the **Select** selector to apply it.

The destination path must not contain double quotes, line feeds, or carriage returns.
These characters cannot be stored safely as a theme value. The app rejects such paths
before copying an import and checks theme values again before stopping btop.

The current validator requires UTF-8 text, at least one recognized color definition, and
assignment lines in this form:

```ini
theme[main_bg] = ""
theme[main_fg] = "#cdd6f4"
```

Blank lines and comments are accepted. Assignment lines can have a trailing comment.
Recognized color keys accept `#` followed by two or six hexadecimal digits, or three
space-separated integers from 0 to 255. Empty values are allowed for `main_bg` and keys
ending in `_mid` or `_end`. Unknown keys in syntactically valid assignments are ignored;
a file containing only unknown keys is rejected. See
[BtopThemeStore.swift](../Sources/BtopDesktop/Infrastructure/BtopThemeStore.swift) for the
recognized keys and exact validation rules.

Theme selection stops btop cleanly before recording the selection and restarting it in the
same panel. This preserves options btop saves on exit. If **Save config on exit** is disabled,
the app refuses the change. If shutdown is forced or unsuccessful, the selected theme is
not written. Recovery can restart the prior configuration; an error is shown to the user.
The selector stays disabled while a change is underway.

Bundled themes come from the pinned btop archive. The catalog also includes **Default** and
**TTY**. Imported entries are labeled **(Imported)** and selected by absolute path, keeping
them distinct from bundled entries with the same filename. A theme preview temporarily bypasses
grayscale; configured grayscale resumes after Settings loses focus or closes.

## What Restore Defaults changes

The Settings restore action resets the panel's presentation values and attempts to show desktop
icons. It preserves interactive mode, btop options, the selected theme, and imported themes.
It is not a complete deletion of application data.

## Backups and manual edits

Quit the application before editing or backing up its configuration. Back up
`~/Library/Application Support/BtopDesktop/` for btop options and imported themes. Presentation
preferences are stored separately in the `local.btop.desktop` UserDefaults domain; developers
can inspect them with:

```sh
defaults read local.btop.desktop
```

Finder's desktop-icon visibility is a global setting and survives application exit. Restore it
through the menu or Settings before removing the app if you want the icons visible.

Implementation: [AppPreferences](../Sources/BtopDesktop/App/AppPreferences.swift),
[configuration store](../Sources/BtopDesktop/Infrastructure/BtopConfigurationStore.swift),
[theme catalog](../Sources/BtopDesktop/Infrastructure/BtopThemeCatalog.swift), and
[theme configuration edits](../Sources/BtopDesktop/Infrastructure/BtopConfigurationStore+Theme.swift).
