#!/bin/bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/NutanSurvase/SlackScribe/main"

# Skips Homebrew's own auto-update step. On a machine that hasn't updated
# Homebrew in a while, that auto-update can trigger a dependency-upgrade
# confirmation prompt mid-install — this installer doesn't need the latest
# formula index, just for ollama/hammerspoon to install cleanly.
export HOMEBREW_NO_AUTO_UPDATE=1
export NONINTERACTIVE=1
# Skips Homebrew's routine 30-day cache cleanup, which sometimes returns a
# non-zero exit code on its own (e.g. a permission hiccup deleting an old
# log) even when the actual install succeeded -- with `set -e` that was
# silently aborting the rest of this script right after ollama installed.
# This installer has no need for that unrelated maintenance step to run.
export HOMEBREW_NO_INSTALL_CLEANUP=1

echo "== SlackScribe installer =="

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew not found. Install it first from https://brew.sh, then re-run this script."
  exit 1
fi

echo "-- Installing Ollama (runs the local AI model)"
brew install ollama
brew services start ollama

echo "-- Downloading the model (qwen2.5:7b-instruct, ~4.7GB, one-time)"
ollama pull qwen2.5:7b-instruct

echo "-- Installing Hammerspoon (runs the hotkeys)"
brew install --cask hammerspoon

echo "-- Installing the SlackScribe config"
mkdir -p ~/.hammerspoon
curl -fsSL "$REPO_RAW_BASE/slackscribe.lua" -o ~/.hammerspoon/init.lua

echo "-- Adding Hammerspoon as a login item (so hotkeys are always ready)"
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Hammerspoon.app", hidden:false}' >/dev/null 2>&1 || true

echo "-- Launching Hammerspoon"
open -a Hammerspoon

cat <<'EOF'

== One manual step left ==
Hammerspoon should show its own Preferences window with an "Enable Accessibility"
button -- click that (or go to System Settings -> Privacy & Security ->
Accessibility and turn it on there). This lets it simulate copy/paste for you --
that's all it's used for. Then click the Hammerspoon menu bar icon -> Reload
Config. To confirm it worked, menu bar icon -> Console should show a line for
each of the 7 hotkeys.

You're set. Hotkeys: ⌘⇧R ⌘⇧G ⌘⇧D ⌘⇧↑ ⌘⇧↓ ⌘⇧S ⌘⇧X (see README for what each does).
EOF
