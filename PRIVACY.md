# Privacy

Claude Code Switcher is a local macOS utility. It does not include analytics, telemetry, crash reporting, or any bundled remote service.

## Local Files Read

The app reads the user's Claude Code configuration and Skill directories at runtime:

- `~/.claude/settings.json`
- `~/.claude/skills`
- `~/.claude/plugins/installed_plugins.json`
- Installed plugin Skill folders referenced by Claude Code

These paths are read from the user's own machine. They are not part of this repository.

## Local Files Written

The app writes only local configuration needed for its features:

- `~/.claude/settings.json` when applying a backend mode
- `~/Library/Application Support/ClaudeCodeSwitcher/backend-profiles.json` for custom backend profiles, without API keys
- `~/Library/Application Support/ClaudeCodeSwitcher/skill-summaries.json` for cached Skill summaries

## Secrets

API keys are stored in macOS Keychain. They are not written to project files, screenshots, GitHub, or the custom backend JSON file.

## Network Use

The app makes network requests only when the user explicitly checks or updates Claude Code, or when Skill summaries are enabled:

- Claude Code version checks call npm registry tooling through the local shell.
- Claude Code updates run the local npm update command.
- Skill summaries call the summary backend selected by the user.

If Skill summaries are set to "Off", no summary-generation network request is made.

## Repository Hygiene

Build products, local verification screenshots, Codex workspace metadata, and generated artifacts are intentionally ignored by `.gitignore`.
