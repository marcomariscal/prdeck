# Contributing to PRDeck

Thanks for your interest in contributing!

## Quick start (dev)

Prereqs:
- macOS 14+
- Xcode (with command line tools)

Clone and build:

```sh
git clone https://github.com/marcomariscal/prdeck.git
cd prdeck
xcodebuild -workspace PRDeck.xcworkspace -scheme PRDeck -destination 'platform=macOS' build
```

Run Swift package tests:

```sh
swift test --package-path PRDeckPackage
```

## Filing issues

- Bugs: use the [bug report template](.github/ISSUE_TEMPLATE/bug_report.yml) and include steps to reproduce + logs if possible.
- Feature requests: use the [feature request template](.github/ISSUE_TEMPLATE/feature_request.yml) and describe the workflow you’re trying to improve.

## Pull requests

- Keep PRs focused (one change/feature per PR).
- Include screenshots or a short screen recording for UI changes.
- If you touch install/release bits, update [`README.md`](README.md) and/or [`RELEASING.md`](RELEASING.md).
- By participating, you agree to follow [`CODE_OF_CONDUCT.md`](CODE_OF_CONDUCT.md).
