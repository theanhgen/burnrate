# burnrate App Store Package Final Verdict (2026-05-08)

## Verdict

**Conditional no-go for submission today.**

The package is close, but three pre-submit items remain:

1. [BIT-42](/BIT/issues/BIT-42) must be resolved (`in_review`) so Gemini auth recovery is fully native in MAS.
2. MAS screenshots must be recaptured with MAS-only providers (current demo hero set still includes Kimi).
3. App Store category must be set to **Developer Tools** as primary (CEO decision in [BIT-40](/BIT/issues/BIT-40)); current plist value is Utilities.

If these three are complete, this package is ready to submit.

## Review Against BIT-114 Scope

### 1) App title + subtitle

Current:
- Name: `burnrate`
- Subtitle: `AI Quota & Usage Monitor`

Assessment:
- Clear, but search intent is better if the title itself includes one high-value keyword (`AI Quota`).

Recommendation:
- Name: `burnrate: AI Quota Monitor`
- Subtitle: `Track Claude, Codex, Gemini`

### 2) Description copy (first two lines)

Current opening is accurate but generic. The above-the-fold should lead with user pain and outcome.

Recommended first two lines:

> Do not get blocked mid-flow by hidden AI quota limits.
> burnrate tracks Claude, Codex, Gemini, Copilot, Bedrock, MiniMax, and Alibaba usage from your menu bar and warns you before limits hit.

### 3) Screenshots and screenshot story

BIT-39 delivered valid dimensions and a strong narrative arc, but current capture content is not submission-safe yet because the demo set includes Kimi.

Assessment:
- Narrative quality: good
- Submission safety: not yet acceptable

Required before upload:
- Replace Kimi in `DemoProvider.createHeroSet()` with Bedrock or MiniMax
- Recapture all 5 screenshots
- Re-verify 1280x800 (or another valid 16:10 family) for each image

Recommended caption flow:
1. One view for all AI quotas
2. Catch burn-rate risk before reset
3. Instant critical alerts in menu bar
4. Enable only the providers you use
5. Light and dark themes for daily workflow

### 4) Pricing

Decision from [BIT-40](/BIT/issues/BIT-40) remains correct: **Free at launch, no IAP**.

Rationale still holds:
- Minimize install friction while the product establishes App Store signal.
- Avoid monetization complexity before retention baseline.
- Better aligned with current trust-building stage (MAS Lite positioning).

### 5) Category placement

Decision from [BIT-40](/BIT/issues/BIT-40) should stand: **Developer Tools primary**.

Current handover still references Utilities as primary. This should be corrected before submission metadata is finalized.

### 6) BIT-42 dependency impact on positioning/copy

Yes, it changes copy boundaries.

Until [BIT-42](/BIT/issues/BIT-42) is done:
- Do not claim seamless in-app auth recovery.
- Do not imply zero setup friction.

Safe wording right now:
- "One-time credential setup"
- "Tracks usage locally on your Mac"

After BIT-42 is done, stronger claim can be added:
- "Handles expired Gemini auth with native in-app recovery (no terminal steps)."

## Final Metadata Draft (Ready Once Gates Clear)

### Name (max 30)
`burnrate: AI Quota Monitor`

### Subtitle (max 30)
`Track Claude, Codex, Gemini`

### Promotional Text (max 170)
`See AI quota risk before it blocks your coding flow. Menu-bar monitoring for Claude, Codex, Gemini, Copilot, Bedrock, MiniMax, and Alibaba.`

### Keywords (max 100)
`ai,quota,usage,monitor,menubar,claude,codex,gemini,copilot,bedrock,developer,coding,tracker,mac`

### Description (updated)

Monitor AI coding usage limits directly from your macOS menu bar.

burnrate gives you one place to track quota status across 7 providers and warns you before limits interrupt your workflow.

KEY FEATURES

- Unified quota dashboard for Claude, Codex, Gemini, GitHub Copilot, AWS Bedrock, MiniMax, and Alibaba Coding Plan
- Burn-rate warnings that account for pace, not just static percentages
- Color-coded provider health (green/yellow/red)
- Native macOS notifications for warning and critical states
- Light and dark themes
- Privacy-first local utility: credentials stay on your Mac

REQUIREMENTS

- macOS 15.0 or later
- Active account/API access for providers you choose to monitor
- One-time credential folder access for supported providers

## Go/No-Go Rule

Proceed to App Store Connect submission only when all are true:

1. [BIT-42](/BIT/issues/BIT-42) = done
2. Screenshot pack recaptured with MAS-only providers
3. Category metadata set to Developer Tools primary
