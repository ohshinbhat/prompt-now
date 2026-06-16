cask "prompt-now" do
  version "0.1.0"
  sha256 "REPLACE_WITH_SHA256_FROM_scripts/package-homebrew.sh"

  url "https://github.com/OWNER/prompt-now/releases/download/v#{version}/PromptNow-#{version}-macos.zip"
  name "Prompt Now"
  desc "Menu bar reminder for returning to Codex or Claude prompts"
  homepage "https://github.com/OWNER/prompt-now"

  depends_on macos: ">= :ventura"

  app "Prompt Now.app"

  zap trash: [
    "~/Library/Preferences/com.promptnow.PromptNow.plist",
  ]
end
