# Privacy Policy

Last updated: 2026-01-07

PRDeck is a local macOS app. It does not include analytics, tracking, ads, or telemetry.

## What PRDeck accesses

- **GitHub data (via `gh`)**: PRDeck calls the GitHub CLI (`gh`) to fetch pull requests and repository lists using your existing `gh` authentication.
- **Clipboard**: PRDeck copies URLs to your clipboard when you click items that copy links.
- **Browser**: PRDeck opens URLs in your default browser when you double-click or use “Open” actions.

## What PRDeck stores locally

PRDeck stores preferences and best-effort caches on your machine:

- **Preferences (UserDefaults)**: UI settings like filter mode, repo include/exclude lists, zoom level, and theme.
- **Cache files (Application Support)**:
  - `~/Library/Application Support/PRDeck/snapshot.json` (cached PR list)
  - `~/Library/Application Support/PRDeck/repos.json` (cached repo directory)

You can delete these at any time to clear cached data.

## What PRDeck does not do

- No analytics / telemetry
- No third-party tracking
- No ads
- No selling or sharing of your data

## Network

PRDeck does not talk directly to GitHub servers itself; it shells out to `gh`, which performs any network requests needed to GitHub (or your configured GitHub Enterprise host). PRDeck does not collect or transmit your GitHub credentials.

## Contact

If you have privacy questions, please open an issue in this repository.
