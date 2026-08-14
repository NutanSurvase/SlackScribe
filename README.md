# SlackScribe

Rephrase and draft your Slack replies in place, without ever leaving Slack or opening ChatGPT/Claude in another tab.

Runs entirely on your own Mac. No API key, no subscription, no internet call — a local AI model does the rewriting, and a small automation tool does the copy/paste/hotkey work.

**One-time setup** — install it once, then the hotkeys just work from then on (auto-starts at login). See [SETUP.md](SETUP.md) for installation instructions.

## How it works

Two small local tools work together:

- **Ollama** — a small AI model that runs entirely on your Mac. Reads your text, writes the rewrite — never touches the internet.
- **Hammerspoon** — binds the hotkeys and simulates copy/paste, since Slack Desktop has no plugin system of its own.

What happens when you press a hotkey:

1. You select text in Slack.
2. Hammerspoon copies it, the same way ⌘C would.
3. It's sent to Ollama, running locally on your Mac — never over the internet.
4. Ollama rewrites it and hands the result back.
5. Hammerspoon pastes it back into the same box, highlighted so you can see what changed.

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
- Two models, each swappable independently at the top of `init.lua` (pull any replacement via `ollama pull <model>` first): `OLLAMA_MODEL` (`qwen2.5:7b-instruct`) handles rephrase/draft/tone, and `OLLAMA_MODEL_SUMMARIZE` (`qwen2.5:14b-instruct`) handles `⌘⇧S` specifically, since it needs to track who-said-what-to-whom more carefully on long threads.
- By default the hotkeys only fire while Slack is the frontmost app — in any other app, the same keystroke passes through untouched (so a browser's own `⌘⇧R` refresh still works, for example). Flip `SLACK_ONLY` to `false` near the top of `init.lua` to make them global instead.

## Setup

See **[SETUP.md](SETUP.md)** for installation steps, requirements, and troubleshooting.
