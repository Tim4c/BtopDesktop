# Testing and validation

[Documentation index](index.md) · [Project home](../README.md)

## Automated checks

The [CI workflow](../.github/workflows/ci.yml) runs on pushes to `main`, pull requests, and
manual dispatches in GitHub Actions. It uses GitHub's Apple Silicon `xcode-27` runner
(currently in preview) to build the complete app with ad hoc signing, run strict lint and
the test suite, and verify the application signature. It installs the Metal Toolchain
component if the runner does not already provide it. No signing secrets are required.

The app is assembled before testing so the real-btop tests can run. Tests requiring a
display may still skip in CI; physical Mission Control, Exposé, and Spaces checks remain
manual. The workflow validates changes without publishing an application release.

Run from the repository root on the supported macOS/Apple Silicon environment:

```sh
scripts/lint.zsh
swift test
codesign --verify --deep --strict BtopDesktop.app
```

Build the application first with `scripts/build-app.zsh` for tests that use the bundled real
btop binary. These checks are explicitly skipped when their bundle prerequisites are missing.
A package compilation alone does not assemble the app. Display-dependent tests may also skip
when no display is available; report skips along with failures.

For focused work:

```sh
swift test --filter OverviewBlurRenderingTests
swift test --filter DesktopOverviewTests
swift test --filter DesktopIconVisibilityControllerTests
swift test --filter NativeRuntimeTests
swift test --filter NativeThemeRestartTests
```

SwiftLint is a SwiftPM dependency/build plugin. The lint script runs strict mode, so warnings
can fail the check. `scripts/lint.zsh --fix` applies supported fixes before strict validation;
it does not solve structural violations. `.swiftlint.yml` covers Sources, Tests, and
Package.swift and excludes downloaded/build outputs. Current warning/error limits are
400/500 file lines, 250/350 type-body lines, and 10/20 cyclomatic complexity.

## Coverage map

| Test files | Main behavior covered |
| --- | --- |
| `AppPreferencesTests` | Defaults, persistence, snapshots, invalid stored values |
| `DesktopAppearanceStateTests` | Focus, previews, grayscale, and resize-guide decisions |
| `SettingsWindowControllerTests`, `SettingsThemeSelectionTests` | Settings callbacks, layout, preview endings, icon error rollback, theme selection |
| `BtopThemeStoreTests`, `ThemeDropZoneTests` | Theme validation, rejection of unusable destination paths, import, catalog, and file-drop behavior |
| `DesktopIconVisibilityControllerTests` | Preference restoration after restart failure, absent keys, rollback errors, and main-actor responsiveness |
| `TerminalEscapeFilterTests` | Escape delivery, modifier handling, and release consumption after focus loss |
| `DesktopOverviewTests` | Dock state decoding, Show Desktop precedence, and which states enable blur |
| `OverviewBlurRenderingTests` | Immediate fixed blur/removal, grayscale composition, hidden-terminal updates, and endpoint attachment |
| `NativeRuntimeTests` | PTY lifecycle, input/resize, clean and forced shutdown, rejection of invalid themes without stopping btop |
| `NativeTerminalTests` | Native rendering, appearance, keyboard, resize, reveal readiness, and stale callbacks |
| `NativeBtopIntegrationTests`, `NativeThemeRestartTests` | Real btop rendering, Settings integration, saved options, and theme restarts |

The complete sources are in [Tests/BtopDesktopTests](../Tests/BtopDesktopTests).
`MemoryDefaults` isolates preferences, `NativeFixture` creates a temporary Python PTY child
with configurable interrupt handling. Fixed overview blur tests assert layer state immediately,
without waiting for animation frames. Finder tests inject simulated commands, leaving real
system preferences untouched. Real terminal rendering tests still use live scheduling.

## Manual validation checklist

Record the macOS version, architecture, display topology and refresh rate, app build/signing
identity, Accessibility status, and btop theme/options when reporting results.

| Scenario | Expected result |
| --- | --- |
| Fresh preferences / first launch | Centered 75% × 55% panel on the pointer's screen; Wallpaper mode |
| Wallpaper clicks | Desktop receives clicks; btop never acquires click focus |
| Enable interaction | Panel stays inactive until explicitly clicked |
| Click terminal / lose focus | Active appearance after click; inactive appearance after focus loss |
| Open/close Settings | Click focus is cleared; another terminal click is needed |
| Escape inside/outside terminal | With Accessibility access, focused btop receives plain Escape once; outside input remains normal |
| Appearance previews | Previewed state is visible and ends when Settings loses focus/closes |
| Size, font, link, anchors | Preferences persist; terminal remains visible and its grid resizes |
| Hide/show icons | Finder applies the global setting; disabling restores icons |
| Import/select theme | Validation and replacement confirmation work; btop restarts and keeps saved options |
| Theme change during quit | Shutdown wins; no unintended replacement process remains |
| Mission Control and App Exposé | Fixed radius 3 after detection; blur clears after exit |
| Cancel/reopen overview | Latest confirmed state determines blur; no predicted progress remains |
| Keyboard overview transition | Same fixed blur as trackpad activation, without animation |
| Show Desktop | Blur is removed immediately after Show Desktop is detected |
| Spaces/full screen/display changes | Placement, focus, and visibility remain consistent with desktop-level behavior |
| Normal quit and btop quit | App closes; configuration is saved; no child remains |

Repeat overview tests under frequent btop redraws, with grayscale on/off, and on every
available display/refresh rate. Check Accessibility denial: the panel should remain sharp.
Automated tests do not replace physical-display validation for detection latency, Spaces, or Exposé.

## Reporting failures

Include the shortest reproduction, expected/actual behavior, relevant logs, and whether
the problem occurs with the assembled bundle or only a test fixture. For blur, distinguish
trackpad from keyboard activation and note whether Mission Control itself also stutters.
See [Troubleshooting](troubleshooting.md) for log locations and [Overview transitions](overview-transitions.md)
for the state-detection and fixed-filter pipeline.

## Latest local validation

On 2026-10-20, after replacing gesture-driven blur with a fixed state-based filter:

- The suite reported 51 tests with no failures; three real-btop tests were initially skipped
  because the assembled app was absent.
- `scripts/build-app.zsh` rebuilt and verified the signed application. All three skipped
  real-btop integration tests were then rerun successfully.
- Strict SwiftLint reported no violations.

This validates 51 distinct tests. Physical Mission Control, Exposé, and Spaces behavior
still needs manual validation; automated filter checks do not establish detection latency.
