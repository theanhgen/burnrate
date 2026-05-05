# burnrate

[![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/macOS-15%2B-blue.svg)](https://developer.apple.com)

**burnrate** is a macOS menu bar app that monitors AI coding assistant usage quotas — so you always know where your budget is going before it runs out.

![burnrate screenshot](docs/screenshots/app-features.png)

> **Screenshot shows the direct-download build (14 providers).** The Mac App Store version supports 7 providers and excludes CLI-dependent probes. See [Mac App Store Build](#mac-app-store-build) below.

## Providers

| Provider | Mac App Store | Direct Download |
|---|---|---|
| Claude (Anthropic) | ✅ | ✅ |
| Codex (OpenAI) | ✅ | ✅ |
| Gemini (Google) | ✅ | ✅ |
| GitHub Copilot | ✅ | ✅ |
| AWS Bedrock | ✅ | ✅ |
| MiniMax | ✅ | ✅ |
| Alibaba Coding Plan | ✅ | ✅ |
| Antigravity | ❌ | ✅ |
| Z.ai (GLM) | ❌ | ✅ |
| Amp Code | ❌ | ✅ |
| Kimi (Moonshot) | ❌ | ✅ |
| Kiro | ❌ | ✅ |
| Cursor | ❌ | ✅ |
| Mistral | ❌ | ✅ |

CLI-based providers (Antigravity, Z.ai, Amp Code, Kimi, Kiro, Cursor, Mistral) require direct process execution that the App Sandbox blocks.

## Features

- **Menu bar always-on** — quota status visible at a glance, no dashboards to open
- **Burn rate warnings** — pace-aware alerts based on whether you're on track to exhaust quota before the period resets, not arbitrary percentage thresholds
- **Color-coded health indicators** — Green/Yellow/Red progress bars per provider
- **System notifications** — warning and critical alerts per provider
- **Themes** — Dark and Light
- **macOS Widgets** — at-a-glance quota status from the menu bar widget

### Direct Download Only

- **14 providers** — full set including all CLI-based probes
- **MCP server** — expose quota data to Claude and other MCP-compatible tools
- **Session monitoring** — Claude Code session start/end tracking via hook server
- **Extensions** — add custom providers via drop-in extension folders (`~/.burnrate/extensions/`)

## Mac App Store Build

The Mac App Store version runs in Apple's App Sandbox. All sandbox-incompatible features are disabled at build time via `#if MAS_BUILD` guards — no hidden features, no bait-and-switch.

**Included in the MAS build (7 providers):**
- Claude · Codex · Gemini · GitHub Copilot · AWS Bedrock · MiniMax · Alibaba Coding Plan
- Menu bar dashboard, burn-rate warnings, system notifications
- Light / Dark themes, macOS Widgets

**Requires the direct download:**
- CLI-based providers (Antigravity, Z.ai, Amp Code, Kimi, Kiro, Cursor, Mistral)
- MCP server, session monitoring, extension system

Full capability comparison: [docs/MAS_CAPABILITY_TABLE.md](docs/MAS_CAPABILITY_TABLE.md)

## Installation

### Mac App Store
Coming soon.

### Direct Download

Grab the signed DMG or ZIP from [GitHub Releases](https://github.com/theanhgen/burnrate/releases/latest).

### Build from Source

```bash
git clone https://github.com/theanhgen/burnrate.git
cd burnrate
brew install tuist
tuist install
tuist generate
open burnrate.xcworkspace
```

The project uses [Tuist](https://tuist.io) for Xcode project generation. `*.xcodeproj` and `*.xcworkspace` are git-ignored — always run `tuist generate` after cloning.

## Architecture

Three-layer structure with `QuotaMonitor` as the single source of truth:

| Layer | Location | Purpose |
|-------|----------|---------|
| Domain | `Sources/Domain/` | Business logic, models, protocols |
| Infrastructure | `Sources/Infrastructure/` | Probes, storage, network |
| App | `Sources/App/` | SwiftUI views (no ViewModel) |

Shared layers: `CloudSync` (CloudKit for iOS), `WidgetData` (macOS + iOS widgets).

Full docs: [docs/architecture/ARCHITECTURE.md](docs/architecture/ARCHITECTURE.md)

## Contributing

Pull requests welcome. To add a new provider follow the TDD pattern used in the existing probes — see `AntigravityUsageProbe` as the simplest reference.

## License

MIT
