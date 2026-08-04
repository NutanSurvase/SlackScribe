#!/bin/bash
set -e

REPO_RAW_BASE="https://raw.githubusercontent.com/NutanSurvase/SlackScribe/main"

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
macOS will prompt (or go to System Settings -> Privacy & Security -> Accessibility)
to grant Hammerspoon permission. This lets it simulate copy/paste for you --
that's all it's used for. Turn it on, then click the Hammerspoon menu bar icon
-> Reload Config.

You're set. Hotkeys: ⌘⇧R ⌘⇧G ⌘⇧D ⌘⇧↑ ⌘⇧↓ ⌘⇧S ⌘⇧X (see README for what each does).
EOF
