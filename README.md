# Claude Code Switcher

A native macOS utility for switching the global Claude Code backend without editing `~/.claude/settings.json` by hand.

It keeps the common presets simple, while still allowing custom Anthropic-compatible backends for people who use their own API gateway or model provider.

[简体中文说明](README.zh-CN.md)

## Screenshots

![Backend switcher](docs/images/backend.png)

![Custom backend](docs/images/custom-backend.png)

## Features

- Switch future `claude` CLI sessions between:
  - Claude subscription
  - DeepSeek V4 Pro
  - DeepSeek V4 Flash
  - Custom Anthropic-compatible backends
- Store API keys in macOS Keychain.
- Switch the app interface between Chinese and English.
- Check and update Claude Code without opening Terminal.
- Manage Claude Code Skills:
  - scan personal and plugin Skills
  - view Chinese summaries and usage guidance
  - filter by category
  - pause and resume individual Skills
  - reveal, uninstall, and check updates where supported
- Choose which configured backend is used to generate Skill summaries, or turn summaries off entirely.

## Requirements

- macOS 14 or later
- Claude Code installed and available as `claude`
- A Claude subscription, or an API backend compatible with Anthropic's Messages API

This app is macOS-only. It uses SwiftUI/AppKit, macOS Keychain, and the local Claude Code config path.

## Install

Download the latest release zip from GitHub Releases, unzip it, and drag `Claude Code Switcher.app` into `/Applications`.

If macOS says the app is from an unidentified developer, right-click the app, choose Open, and confirm once. A future notarized build can remove this extra step.

## Quick Start

1. Open `Claude Code Switcher`.
2. Choose a backend.
3. If the backend needs an API key, paste it and click Save Key.
4. Click Apply Mode.
5. Open any folder in Terminal and run `claude`.

The change affects new Claude Code CLI sessions. Restart an already-open Claude Code session if it does not pick up the new route immediately.

## Custom Anthropic-Compatible Backend

The first public version supports custom Anthropic-compatible backends only. It does not convert OpenAI, Gemini, or Ollama protocols by itself.

To add one:

1. Click Custom Backend.
2. Enter a friendly name.
3. Enter the backend base URL, for example `https://api.example.com/anthropic`.
4. Enter the primary model.
5. Enter the fast model. It can be the same as the primary model.
6. Enter the API key.
7. Click Save and Apply.

The app writes these Claude Code routing keys:

- `ANTHROPIC_BASE_URL`
- `ANTHROPIC_AUTH_TOKEN`
- `ANTHROPIC_MODEL`
- `ANTHROPIC_DEFAULT_OPUS_MODEL`
- `ANTHROPIC_DEFAULT_SONNET_MODEL`
- `ANTHROPIC_DEFAULT_HAIKU_MODEL`
- `ANTHROPIC_SMALL_FAST_MODEL`
- `CLAUDE_CODE_SUBAGENT_MODEL`

Switching back to Claude subscription removes those routing keys.

## Skill Summaries

Skill summaries are optional.

On the Skill page, choose a summary model from the text-bubble menu:

- Off: no summary network request is made.
- Any configured API backend: the app uses that backend's Keychain API key and model to summarize Skill files.

If no summary model is selected, the app shows the original Skill description.

## Privacy

Claude Code Switcher is local-first:

- API keys are stored in macOS Keychain.
- Custom backend profiles are stored locally without API keys.
- The repository does not contain your local Claude settings, Skills, build output, or screenshots.
- Skill summary requests are sent only to the summary backend you choose.

See [PRIVACY.md](PRIVACY.md) for details.

## Build From Source

```bash
swift build --product "Claude Code Switcher"
swift run SettingsDocumentTestRunner
```

Run or install locally:

```bash
./script/build_and_run.sh run
./script/build_and_run.sh install
```

Create a release zip:

```bash
./script/package_release.sh
```

## Limitations

- macOS only.
- Custom backend support is Anthropic-compatible only.
- The app is not affiliated with Anthropic, Claude, DeepSeek, or any model provider.
- Plugin-level Skill behavior is controlled by Claude Code. Per-Skill pause/resume is implemented locally by temporarily renaming that Skill's `SKILL.md` file and can be reversed from the app.

## License

MIT
