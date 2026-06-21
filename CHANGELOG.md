# Changelog

## 1.0.6

- Added dynamic local Ollama Qwen model discovery from `http://localhost:11434/api/tags`.
- Ollama Qwen models now appear as selectable backends using Ollama's Anthropic-compatible API.
- Ollama Qwen models can also be selected as local Skill summary providers.
- Ollama backends use the local `ollama` auth token automatically and do not ask for an API key.
- Improved backend layout to scroll when many local models are available.

## 1.0.5

- Added a global Claude Code Effort control to the backend status panel.
- Effort can be set to Auto, Low, Medium, High, XHigh, or Max before opening new Claude Code CLI sessions.
- Persisted Effort settings into Claude Code's user settings while preserving unrelated configuration.

## 1.0.4

- Added batch Skill summary generation from the Skill library menu.
- Batch generation respects the current category filter and skips Skills that already have generated summaries.

## 1.0.3

- Fixed Claude Code version checks from the macOS app by adding common CLI install paths such as `~/.local/bin` and Homebrew paths.
- Switched latest-version lookup to Claude's official release endpoint, with npm as a fallback only.
- Changed in-app updates to use `claude update` instead of `npm update`.
- Added an in-app Claude Code install action when the CLI is not found.
- Improved Skill summary generation with larger output limits, retry-on-truncation, more tolerant response decoding, and a new cache version to avoid reusing truncated old summaries.
- Added a full Summary section in Skill details so long summaries and failure details are visible.

## 1.0.2

- Fixed language switching for backend cards, Skill controls, status lines, and window titles.
- Changed Skill summary provider selection so it no longer regenerates summaries automatically.
- Added cache-first Skill summary behavior; manual generation is explicit, while newly discovered Skills can still be summarized automatically when a provider is configured.
- Improved Skill summary failure messages with API key, HTTP status, endpoint, model, and rate-limit hints.

## 1.0.1

- Added an in-app Chinese/English language switcher.
- Skill usage guidance and generated Skill summaries now follow the selected UI language.

## 1.0.0

- Added built-in Claude subscription, DeepSeek V4 Pro, and DeepSeek V4 Flash backend profiles.
- Added custom Anthropic-compatible backend profiles.
- Added per-profile API key storage in macOS Keychain.
- Added selectable Skill summary provider, including an off mode.
- Added Claude Code version check and update actions.
- Added Claude Code Skill management, category filtering, update checks, reveal, uninstall, pause, and resume.
- Added public release documentation, privacy notes, and CI.
