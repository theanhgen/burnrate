# burnrate MAS Capability Truth Table

Authoritative comparison between `burnrate-mas` (Mac App Store build) and `burnrate`
(direct-distribution / Sparkle build). Derived from `BurnrateApp.swift` `#if MAS_BUILD` blocks
and `Project.swift` target definitions.

---

## 1. Provider Coverage

| Provider | burnrate (direct) | burnrate-mas (MAS) | Notes |
|---|---|---|---|
| Claude (Anthropic) | ✅ | ✅ | MAS uses API-only probe (credential file via bookmark) |
| Codex (OpenAI) | ✅ | ✅ | MAS uses API-only probe (credential file via bookmark) |
| Gemini (Google) | ✅ | ✅ | MAS uses bookmark-scoped file access for auth token |
| GitHub Copilot | ✅ | ✅ | API probe; same in both builds |
| AWS Bedrock | ✅ | ✅ | API probe; same in both builds |
| MiniMax | ✅ | ✅ | API probe; same in both builds |
| Alibaba Coding Plan | ✅ | ✅ | MAS uses no-op cookie provider (browser cookies unavailable in sandbox) |
| Antigravity | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |
| Z.ai (GLM) | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |
| Amp Code | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |
| Kimi (Moonshot) | ✅ | ❌ | CLI + API; CLI variant blocked by sandbox |
| Kiro | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |
| Cursor | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |
| Mistral | ✅ | ❌ | CLI-only probe; blocked by App Sandbox |

**MAS provider count: 7 of 14**

---

## 2. Feature Coverage

| Feature | burnrate (direct) | burnrate-mas (MAS) | Notes |
|---|---|---|---|
| Quota dashboard (menu bar) | ✅ | ✅ | Core feature, identical |
| Color-coded health indicators | ✅ | ✅ | Green/Yellow/Red, identical |
| Burn-rate pace warnings | ✅ | ✅ | Threshold-based, identical |
| System notifications | ✅ | ✅ | Warning + critical alerts, identical |
| Light / Dark theme | ✅ | ✅ | Identical |
| CLI theme | ✅ | ✅ | Identical |
| macOS Widgets (menu bar widget) | ✅ | ✅ | Via App Group, identical |
| iOS companion (CloudKit sync) | build flag | build flag | `ENABLE_CLOUDSYNC`; not MAS-specific |
| Manual refresh | ✅ | ✅ | Identical |
| Provider enable/disable toggle | ✅ | ✅ | Identical |
| Credential file access (NSOpenPanel) | ✅ | ✅ | MAS uses security-scoped bookmarks |
| Claude CLI probe mode | ✅ | ❌ | Sandbox blocks direct CLI execution |
| Codex RPC probe mode | ✅ | ❌ | Sandbox blocks local IPC socket |
| Hook server (Claude Code events) | ✅ | ❌ | `#if !MAS_BUILD`; HTTP localhost server |
| Session file scanner | ✅ | ❌ | `#if !MAS_BUILD`; reads `~/.claude/` directly |
| Session start/end notifications | ✅ | ❌ | Depends on session scanner/hook |
| Extension providers (custom) | ✅ | ❌ | `#if !MAS_BUILD`; filesystem extension loading |
| MCP server / API endpoints | ✅ | ❌ | Served by hook server |
| Sparkle auto-update | ✅ | ❌ | `#if ENABLE_SPARKLE`; MAS uses App Store updates |
| Alibaba browser cookie extraction | ✅ | ❌ | `AlibabaBrowserCookieProvider` blocked by sandbox |

---

## 3. Probe Method Differences

| Provider | Direct build probe(s) | MAS build probe |
|---|---|---|
| Claude | CLI (`/usage`), API, pass-through | API only (bookmark-loaded credential) |
| Codex | RPC (local socket), API | API only (bookmark-loaded credential) |
| Gemini | Filesystem read (gcloud auth) | Filesystem read via security-scoped bookmark |
| GitHub Copilot | API (OAuth token from env/file) | API (same) |
| AWS Bedrock | AWS SDK / API | AWS SDK / API (same) |
| MiniMax | REST API | REST API (same) |
| Alibaba | REST API + browser cookies | REST API only (no cookies) |

---

## 4. Entitlements (MAS build)

File: `Sources/App/entitlements.mas.plist`

| Entitlement | Purpose |
|---|---|
| `com.apple.security.app-sandbox` | Required for MAS |
| `com.apple.security.network.client` | Outbound HTTP/HTTPS to provider APIs |
| `com.apple.security.automation.apple-events` | Inter-process communication |
| `com.apple.security.files.user-selected.read-write` | NSOpenPanel credential folder access |
| `com.apple.security.files.bookmarks.app-scope` | Persist credential folder bookmarks across launches |
| `com.apple.security.application-groups` | Widget data sharing (`group.com.nguyentheanh.burnrate`) |

---

## 5. App Store Listing Copy Constraints

The following claims in `docs/APP_STORE_LISTING_HANDOVER.md` **must be audited** before
submission because they reference capabilities not present in `burnrate-mas`:

| Claim in current copy | MAS status | Required action |
|---|---|---|
| "14 providers broadly" (implied) | ❌ 7 providers in MAS | Rewrite to "7 providers" or "leading AI providers" |
| "Antigravity, Amp Code, Kimi, Kiro, Cursor, Mistral" listed as supported | ❌ Not in MAS | Remove from MAS listing |
| "Z.ai" not currently mentioned but in direct build | N/A | Not in MAS, no action needed |
| Hook / session event integration | ❌ Not in MAS | Do not mention in App Store copy |
| Extension provider support | ❌ Not in MAS | Do not mention in App Store copy |

---

## 6. Screenshot Guidance

Screenshots committed to `docs/screenshots/mas/` must show **only MAS-supported providers and features**.

| Screenshot | Shows | Avoids |
|---|---|---|
| `01-dashboard-dark.png` | 4+ providers from MAS set (Claude, Codex, Gemini, Copilot, Bedrock), dark theme | No Antigravity, Kimi, Cursor, Z.ai etc. |
| `02-dashboard-light.png` | Same layout, light theme | Same exclusions |
| `03-critical-alert.png` | One provider at critical (red) quota level | No hook/session UI |
| `04-settings.png` | Provider toggle list showing MAS 7 providers | No hook settings, no extension config |
| `05-burn-rate.png` | Burn-rate pace warning indicator active | No CLI features visible |

See `scripts/capture-mas-screenshots.sh` for the full capture workflow.
