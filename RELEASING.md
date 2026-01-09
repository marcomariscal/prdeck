# Releasing PRDeck

PRDeck is distributed outside the Mac App Store using **Developer ID signing** + **Apple notarization**.

## GitHub Secrets

The GitHub Actions release workflow expects these repository secrets:

- `APPLE_TEAM_ID`
- `APPLE_CERTIFICATE_P12_BASE64` (Developer ID Application cert exported as `.p12`, base64-encoded)
- `APPLE_CERTIFICATE_PASSWORD` (password used when exporting the `.p12`)
- `APPLE_NOTARYTOOL_ISSUER_ID` (App Store Connect API issuer)
- `APPLE_NOTARYTOOL_KEY_ID` (App Store Connect API key id)
- `APPLE_NOTARYTOOL_KEY_P8_BASE64` (App Store Connect API key `.p8`, base64-encoded)

## Create a release

1. Update the app version (optional)
   - `MARKETING_VERSION` lives in `Config/Shared.xcconfig`
2. Tag a version and push it:

```sh
git tag v0.1.0
git push origin v0.1.0
```

This triggers `.github/workflows/release.yml`, which builds, signs, notarizes, staples, and uploads a `PRDeck-<tag>-macos.zip` asset to the GitHub Release.

## Homebrew cask

The Homebrew cask lives in `Casks/prdeck.rb` and should be updated to the new `version` + `sha256` after publishing a release.
