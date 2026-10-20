# Btop Desktop documentation

[Project home and quick start](../README.md)

Complete user and developer documentation for the behavior implemented in this repository. The
source files linked from each page are the implementation reference; compatibility and pinned
dependencies describe the current build, rather than a promise of broader support.

## For users

| Guide                                        | Contents                                                                    |
| -------------------------------------------- | --------------------------------------------------------------------------- |
| [Getting started](getting-started.md)        | Requirements, first launch, Accessibility permission, first session         |
| [User guide](user-guide.md)                  | Display modes, focus, appearance, size, desktop icons, themes, and quitting |
| [Configuration and themes](configuration.md) | Local data, theme validation, persistence, backups, and reset behavior      |
| [Troubleshooting](troubleshooting.md)        | Common symptoms, logs, known limitations, and useful report details         |

## For developers

| Guide                                             | Contents                                                                          |
| ------------------------------------------------- | --------------------------------------------------------------------------------- |
| [Development and building](development.md)        | Toolchain, vendor installation, assembly, signing, layout, and dependency updates |
| [Architecture](architecture.md)                   | Component ownership, concurrency, PTY data flow, focus, reveal, and shutdown      |
| [Overview transitions](overview-transitions.md)   | Accessibility state detection, fixed blur, latency, and manual validation         |
| [Testing and validation](testing.md)              | Automated checks, coverage map, fixtures, and manual test checklist               |
| [Dependencies and distribution](dependencies.md)  | Pinned components, provenance, bundle contents, signing, and embedded licenses    |
| [Community prereleases and Homebrew](releases.md) | ZIP packaging, draft releases, testing, and the personal tap                      |

Start with Development to build the app, Architecture to understand it, and Testing to validate a
change. User-visible behavior should be documented in the user guides alongside the corresponding
technical explanation when necessary.
