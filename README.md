# SlackScribe

Rephrase and draft your Slack replies in place, without ever leaving Slack or opening ChatGPT/Claude in another tab.

Runs entirely on your own Mac. No API key, no subscription, no internet call — a local AI model does the rewriting, and a small automation tool does the copy/paste/hotkey work.

## What it needs

- A Mac (tested on Apple Silicon)
- [Homebrew](https://brew.sh)
- ~5GB free disk space (for the local model)

## Quick install

```
curl -fsSL https://raw.githubusercontent.com/NutanSurvase/SlackScribe/main/install.sh | bash
```

This runs every step below automatically, except granting the Accessibility
permission — macOS requires that to be a manual click. Prefer to see what
it's doing first? Follow the manual steps instead.

## Manual setup steps

**1. Install Ollama** (runs the local AI model)
```
brew install ollama
brew services start ollama
```

**2. Download the model**
```
ollama pull qwen2.5:7b-instruct
```
This is a one-time ~4.7GB download.

**3. Install Hammerspoon** (runs the hotkeys)
```
brew install --cask hammerspoon
```

**4. Grant Accessibility permission**
Open Hammerspoon once (`open -a Hammerspoon`), then go to **System Settings → Privacy & Security → Accessibility**, and turn on Hammerspoon. This lets it simulate copy/paste on your behalf — that's all it uses this for.

**5. Get the config file and add it**
```
git clone https://github.com/NutanSurvase/SlackScribe.git
mkdir -p ~/.hammerspoon
cp SlackScribe/slackscribe.lua ~/.hammerspoon/init.lua
```

**6. Load it**
Click the Hammerspoon icon in your menu bar → **Reload Config**. You should see a confirmation popup listing the hotkeys.

**7. (Optional) Auto-start at login**
Add Hammerspoon as a login item: **System Settings → General → Login Items → +** → select Hammerspoon.

## How to use it

Works anywhere you can select text, including Slack Desktop:

| Hotkey | What it does |
|---|---|
| `⌘⇧R` | Rephrases your selected draft in place — fixes grammar/tone, keeps facts untouched |
| `⌘⇧G` | Capture the message you're replying to, so the next `⌘⇧R` actually addresses it (expires after 45s) |
| `⌘⇧D` | Draft a full reply from scratch to a message you're stuck on — never fakes an answer you haven't given |
| `⌘⇧↑` | Make the selected text more professional |
| `⌘⇧↓` | Make the selected text more casual |
| `⌘⇧S` | Summarize several selected messages — main points, decisions, open questions, action items |
| `⌘⇧X` | Clear captured context manually |

## Notes

- Everything runs on `localhost` — nothing you type is sent over the internet.
- The model (`qwen2.5:7b-instruct`) can be swapped for a smaller/faster or larger/better one by changing `OLLAMA_MODEL` at the top of `init.lua`, as long as it's pulled via `ollama pull <model>` first.
- By default the hotkeys only fire while Slack is the frontmost app — in any other app, the same keystroke passes through untouched (so a browser's own `⌘⇧R` refresh still works, for example). Flip `SLACK_ONLY` to `false` near the top of `init.lua` to make them global instead.
- If a hotkey ever says "select some text first" right after it should've worked, just try again — it's usually a timing hiccup with the app you're in.
- If a hotkey consistently fails to capture even with text clearly selected, another app may have claimed the same global shortcut (screenshot/recording tools are common culprits). Check for a conflicting hotkey in that app, or rebind the one in `init.lua` to a different combo.
