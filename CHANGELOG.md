# Changelog

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
