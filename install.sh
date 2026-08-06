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
# Homebrew itself can return a non-zero exit code for reasons unrelated to
# whether the actual install worked (a cleanup hiccup, a caveat it treats as
# a warning, etc). Rather than guess which specific case that is, check the
# real-world outcome directly -- if the command now exists, it worked,
# regardless of what brew's own exit code says.
brew install ollama || true
if ! command -v ollama >/dev/null 2>&1; then
  echo "Error: ollama did not install. Try running 'brew install ollama' by itself to see the real error, then re-run this script."
  exit 1
fi
brew services start ollama || true

# `brew services start` hands off to launchd and returns immediately -- the
# actual ollama server process needs a moment to start listening. On a truly
# fresh install (service started for the first time), pulling the model
# right away can lose that race with a "could not connect" error. Wait for
# the server to actually respond before trying, instead of assuming it's
# ready the instant the service command returns.
echo "-- Waiting for the Ollama server to be ready"
ready=0
for i in $(seq 1 15); do
  if curl -fsS http://127.0.0.1:11434 >/dev/null 2>&1; then
    ready=1
    break
  fi
  sleep 1
done
if [ "$ready" -ne 1 ]; then
  echo "Error: the Ollama server never came up. Try running 'ollama serve' in another terminal window, then re-run this script."
  exit 1
fi

echo "-- Downloading the model (qwen2.5:7b-instruct, ~4.7GB, one-time)"
if ! ollama pull qwen2.5:7b-instruct; then
  echo "Error: the model download failed (check your internet connection), then re-run this script."
  exit 1
fi

echo "-- Installing Hammerspoon (runs the hotkeys)"
brew install --cask hammerspoon || true
if [ ! -d "/Applications/Hammerspoon.app" ]; then
  echo "Error: Hammerspoon did not install. Try running 'brew install --cask hammerspoon' by itself to see the real error, then re-run this script."
  exit 1
fi

echo "-- Installing the SlackScribe config"
mkdir -p ~/.hammerspoon || true
if ! curl -fsSL "$REPO_RAW_BASE/slackscribe.lua" -o ~/.hammerspoon/init.lua; then
  echo "Error: couldn't download the config file (check your internet connection), then re-run this script."
  exit 1
fi

echo "-- Adding Hammerspoon as a login item (so hotkeys are always ready)"
osascript -e 'tell application "System Events" to make login item at end with properties {path:"/Applications/Hammerspoon.app", hidden:false}' >/dev/null 2>&1 || true

echo "-- Launching Hammerspoon"
# By this point every essential prerequisite (ollama, the model, the
# Hammerspoon app, the config) is already confirmed to genuinely exist.
# Auto-launching it is a convenience, not a requirement -- if this
# particular hiccups (e.g. a first-launch Gatekeeper check), the person
# can still launch it themselves per the instructions below, so this must
# never be allowed to block the final success message from printing.
open -a Hammerspoon || true

cat <<'EOF'

== One manual step left ==
If you don't see a Hammerspoon window or menu bar icon, launch it yourself:
Cmd+Space -> type "Hammerspoon" -> Enter.

Hammerspoon should show its own Preferences window with an "Enable Accessibility"
button -- click that (or go to System Settings -> Privacy & Security ->
Accessibility and turn it on there). This lets it simulate copy/paste for you --
that's all it's used for. Then click the Hammerspoon menu bar icon -> Reload
Config. To confirm it worked, menu bar icon -> Console should show a line for
each of the 7 hotkeys.

You're set. Hotkeys: ⌘⇧R ⌘⇧G ⌘⇧D ⌘⇧↑ ⌘⇧↓ ⌘⇧S ⌘⇧X (see README for what each does).
EOF
