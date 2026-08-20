# SlackScribe — Setup

← [Back to README](README.md)

## What it needs

- A Mac (tested on Apple Silicon)
- [Homebrew](https://brew.sh)
- ~14GB free disk space (for the two local models — see below)

## Quick install

Needs Homebrew first — skip this if you already have it (check with `brew --version`):
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

Then run the installer:
```
curl -fsSL https://raw.githubusercontent.com/NutanSurvase/SlackScribe/main/install.sh -o /tmp/slackscribe-install.sh && bash /tmp/slackscribe-install.sh
```

(Downloads the script first, then runs it — safer than piping straight into
`bash`, since some of the install steps can otherwise interfere with the
same connection the script is being read from mid-run.)

**Expect ~30-45 minutes total** — most of that is downloading the two AI
models (~14GB combined), so it depends heavily on your internet speed. It
prints progress as it goes, so it's not stuck even if it looks slow.

This runs every step below automatically, except granting the Accessibility
permission — macOS requires that to be a manual click. Prefer to see what
it's doing first? Follow the manual steps instead.

While it runs, you may see 1-2 macOS permission popups — both expected, safe
to approve, see step 1 and step 3 below for what they look like.

## Manual setup steps

**0. Install Homebrew** (skip if you already have it — check with `brew --version`)
```
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```
This asks for your Mac login password in Terminal (a normal `sudo` prompt, needed to install to system folders) — that's expected.

**1. Install Ollama** (runs the local AI model)
```
brew install ollama
brew services start ollama
```
The first time Ollama's background service starts, macOS may show a firewall-style popup like *"Do you want the application to accept incoming network connections?"* — click **Allow**. It only ever listens on your own Mac (`localhost`), never the internet.

**2. Download the models**
```
ollama pull qwen2.5:7b-instruct
ollama pull qwen2.5:14b-instruct
```
One-time downloads, ~4.7GB and ~9GB. The smaller model handles rephrase/draft/tone (fast, a few seconds); the larger one handles `⌘⇧S` summarize specifically — it's slower (~15-20s) but noticeably more reliable on long, messy threads, and `⌘⇧S` already shows a dialog you wait on, so the extra time is less noticeable there.

**3. Install Hammerspoon** (runs the hotkeys)
```
brew install --cask hammerspoon
```
Since this is an app downloaded from the internet, macOS Gatekeeper may block the first launch with *"Hammerspoon can't be opened because it is from an unidentified developer"* or similar. If that happens: right-click Hammerspoon in **Applications** → **Open** → confirm **Open** — only needed once.

**4. Grant Accessibility permission**
The first time Hammerspoon launches, it typically opens its own **Preferences** window showing "WARNING! Accessibility is not enabled!" with an **Enable Accessibility** button — click that (it's the quickest path). Alternatively, go to **System Settings → Privacy & Security → Accessibility** and turn on Hammerspoon there directly. Either way, this only lets it simulate copy/paste on your behalf — that's all it's used for.

You'll also see a one-time system notification like *"Login Item Added — Hammerspoon will open automatically when you log in"* — that's expected, not an error.

If hotkeys still don't respond after enabling Accessibility, also check **System Settings → Privacy & Security → Input Monitoring** and enable Hammerspoon there — a few Macs/macOS versions need both permissions before hotkeys register.

**5. Get the config file and add it**
```
git clone https://github.com/NutanSurvase/SlackScribe.git
mkdir -p ~/.hammerspoon
cp SlackScribe/slackscribe.lua ~/.hammerspoon/init.lua
```
If this is the first `git` command ever run on this Mac, macOS may prompt to install **Command Line Developer Tools** first — accept, wait for that to finish, then re-run the command above.

**6. Load it**
Click the Hammerspoon icon in your menu bar → **Reload Config**. You should see a confirmation popup listing the hotkeys.

To double-check it actually loaded (in case you miss the popup), click the Hammerspoon menu bar icon → **Console**. You should see a line for each hotkey, like:
```
hotkey: Enabled hotkey ⌘⇧R
hotkey: Enabled hotkey ⌘⇧G
hotkey: Enabled hotkey ⌘⇧D
...
```
Seven lines total — one per hotkey — confirms everything's registered correctly.

**7. (Optional) Auto-start at login**
Add Hammerspoon as a login item: **System Settings → General → Login Items → +** → select Hammerspoon.

## Troubleshooting

**The install command stops partway through, or seems stuck:**
- If it prints a specific `Error: ...` message, that tells you exactly what failed (no internet, Homebrew itself failed, etc.) — fix that and re-run the same command; it's safe to run more than once.
- If it's just slow with no error, let it keep running — Homebrew can take a while on a Mac that hasn't been updated in a long time. Don't interrupt it.

**No Hammerspoon window or menu bar icon appears after installing:**
- Launch it yourself: **Cmd+Space** → type "Hammerspoon" → Enter.
- Check it's actually installed: run `brew list --cask hammerspoon` in Terminal — if it says "not installed," re-run the install command above.

**Text rewrites correctly, but no "Rephrased ✓" popup appears:**
- Check whether Slack is in native full-screen mode (its own dedicated desktop Space) — exit full-screen and try again. Hammerspoon's popups don't reliably show over apps running that way.

**A hotkey says "select some text first" right after it should've worked:**
- Just try again — it's usually a one-off timing hiccup with the app you're in.

**A hotkey consistently fails to capture even with text clearly selected:**
- Another app may have claimed the same global shortcut (screenshot/recording tools are common culprits). Check for a conflicting hotkey in that app, or rebind the one in `init.lua` to a different combo.

**A hotkey (especially switching between `⌘⇧S` and the others) suddenly stops working, shows a blank result, or an "Is Ollama running?" alert even though Ollama is running:**
- On a Mac with less RAM, Ollama can run out of GPU memory trying to keep both of SlackScribe's models loaded at once, which crashes mid-request. Fresh installs are already protected against this, but if you installed before this fix, run this once in Terminal, then quit and reopen Hammerspoon:
  ```
  /usr/libexec/PlistBuddy -c "Add :EnvironmentVariables:OLLAMA_MAX_LOADED_MODELS string 1" ~/Library/LaunchAgents/homebrew.mxcl.ollama.plist
  brew services restart ollama
  ```
  (If that first command says the key already exists, you already have this fix — the issue is something else.)
