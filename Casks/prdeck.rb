cask "prdeck" do
  version "0.1.2"
  sha256 "8d90e27dd634a95e572907b59e6c9ffa0d3897c30f2c237f3f038214f89b56e8"

  url "https://github.com/marcomariscal/prdeck/releases/download/v#{version}/PRDeck-v#{version}-macos.zip"

  name "PRDeck"
  desc "Keyboard-first PR inbox for GitHub on macOS"
  homepage "https://github.com/marcomariscal/prdeck"

  depends_on macos: ">= :sonoma"

  app "PRDeck.app"

  zap trash: [
    "~/Library/Application Support/PRDeck",
    "~/Library/Preferences/com.marco.PRDeck.plist",
    "~/Library/Saved Application State/com.marco.PRDeck.savedState",
  ]
end
