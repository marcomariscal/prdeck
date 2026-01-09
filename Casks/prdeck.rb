cask "prdeck" do
  version "0.1.1"
  sha256 "dddeb6c95f32c095a20599f0a3f6c96631ec0901e81167fe530b569c60628978"

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
