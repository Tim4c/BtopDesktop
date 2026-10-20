# Contributing to Btop Desktop

Btop Desktop is a personal macOS project. Bug reports, documentation fixes, and focused pull
requests are welcome. Please discuss larger features or architectural changes in an issue first.

## Report a bug

Search existing issues before opening a new one. Include:

- Your macOS version, Mac model, and whether you built the app from source.
- Steps to reproduce, expected behavior, and actual behavior.
- Relevant screenshots or logs, with private information removed.
- For focus or Mission Control issues: Accessibility permission status, display setup, and
  whether the behavior occurs with keyboard or trackpad activation.

## Set up development

The project currently requires Apple Silicon and macOS 27 or later, plus Xcode with Swift 6
support and the Metal Toolchain component. Follow [Development and building](docs/development.md)
to install dependencies and assemble the application.

Fork the repository, create a branch for your change, and keep the change focused on one issue.
Follow the existing code style and read [Architecture](docs/architecture.md) for the relevant
part of the app.

## Check your change

Quit the running app before rebuilding. From the repository root:

```sh
scripts/build-app.zsh
scripts/lint.zsh
swift test
codesign --verify --deep --strict BtopDesktop.app
```

Build the app before testing so real-btop integration tests can find the bundled runtime.
Some tests require a display; report skipped tests as well as failures. Manually check any
desktop, focus, or Mission Control behavior affected by your change. See
[Testing and validation](docs/testing.md) for the checklist.

For a behavior fix, add a regression test when practical. Update documentation when changing
settings, requirements, or user-visible behavior. Do not commit downloaded dependencies,
application bundles, build products, signing certificates, or private keys.

## Open a pull request

GitHub Actions runs the build, lint, tests, and signature verification for pull requests.
Review the CI results and fix failures related to your change before requesting review.

Explain the problem, what the change does, and how you tested it. Link the related issue if
there is one, and include screenshots for visible UI changes. Mention known limitations and
any checks you could not run.
