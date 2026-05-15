# burnrate App Store Readiness Review (2026-05-05)

## Decision Summary
- **Decision:** Launch `burnrate-mas` first, not `ClaudeBar`.
- **Readiness:** **Conditional** (not submission-ready today).
- **Why:** Core JTBD is stronger in `burnrate` (cross-provider quota visibility + burn-rate alerts). `ClaudeBar` is a narrower surface and weaker standalone acquisition funnel.

## Problem Statement (JTBD)
Developers and AI-heavy teams need to answer: **"Am I on pace to run out of quota or overspend before reset?"**

Evidence in product copy and app behavior:
- README lead value prop is "know where budget is going before it runs out".
- Burn-rate logic is explicitly pace-aware (not static thresholds).
- App is menu-bar-first for low time-to-value.

## Scope Findings

### 1) App Store listing readiness
**Current state:** Not ready.

What exists:
- README has strong base messaging and feature bullets.
- Privacy policy document exists in repo and is hostable.
- Public site already markets App Store availability.

What is missing/blocking:
- No dedicated App Store metadata source-of-truth (name/subtitle/keywords/description/promotional text).
- Screenshot set is incomplete: only `docs/screenshots/app-features.png` exists.
- Existing screenshot is **1198x1393** (portrait), which does not match Mac App Store 16:10 required sizes.

Apple reference requirement for macOS screenshots:
- 16:10 only, one of: `1280x800`, `1440x900`, `2560x1600`, `2880x1800`.

### 2) Value proposition clarity
**Current state:** Strong core proposition, but launch copy is over-claiming for MAS.

Strengths:
- "Know before quota runs out" is clear and outcome-focused.
- Menu bar positioning and "glanceable" value are easy to understand.

Gap/risk:
- Public copy says 14 providers broadly, while App Store build is a reduced set.
- Without explicit MAS feature boundaries, onboarding expectations will mismatch and hurt ratings.

### 3) Which build should launch on App Store
**Recommendation:** Launch `burnrate-mas`.

Evidence:
- A dedicated Mac App Store target already exists (`burnrate-mas`).
- MAS build uses sandbox-safe path and API/bookmark-based credential access.
- MAS build currently ships **7 providers** (Claude, Codex, Gemini, Copilot, Bedrock, MiniMax, Alibaba), while non-MAS has 14 and CLI/hook/extension capabilities.

Product call:
- `burnrate` serves the primary job better than `ClaudeBar`.
- Launch with explicit "supported providers on App Store build" messaging.

### 4) Pricing strategy
**Recommendation:** Launch as **free** (no IAP) for v1 App Store entry.

Rationale:
- **Time-to-Value lens:** lower friction for first install.
- **Signal vs. Noise lens:** need real App Store demand signal before monetization complexity.
- **Retention vs. Acquisition lens:** prioritize activation/retention proof before pricing experiments.

Revisit trigger:
- Consider paid/freemium only after stable retention and evidence of high-frequency usage.

### 5) Missing content checklist
- **Privacy Policy URL:** available candidate: `https://theanhgen.github.io/burnrate/privacy-policy.html`.
- **Support URL:** available candidate: `https://github.com/theanhgen/burnrate/issues`.
- **Category:** currently set to Utilities (`public.app-category.utilities`).
  - Recommendation: test whether **Developer Tools** positioning improves discovery quality vs Utilities.
- **Keywords/subtitle:** not yet defined in a canonical listing document.

### 6) Launch readiness

#### Blockers (must fix before submission)
1. App Store screenshot pack at valid macOS dimensions (1-10 images, coherent narrative).
2. Canonical App Store metadata doc (name/subtitle/keywords/description + feature claims aligned to MAS build).
3. MAS vs non-MAS feature truth table to prevent over-claiming.
4. Confirm final category choice and pricing decision with CEO.

#### Can defer post-launch
1. Localization expansion beyond English.
2. Broad long-tail provider expansion from 7 to 14 in MAS build.
3. Advanced ASO iteration (keyword A/B style changes over time).

## Prioritization Rationale (Lenses)
- **Kano Model:** Quota visibility and reliable provider coverage are must-haves; fancy delighters should not block basics.
- **Value vs. Effort:** Metadata + screenshots + claim alignment are high-value/low-to-medium-effort and should come first.
- **Business Viability:** Clear listing and truthful scope reduce churn/refunds/reviews risk, improving conversion quality.
- **Time-to-Value:** Free launch with clear setup flow maximizes install-to-first-value speed.
- **Dependency Risk:** App Store acceptance is externally gated; mismatched claims or invalid assets are high-risk blockers.
- **Competitive Moat:** Differentiator is cross-provider pace intelligence in menu bar, not just another quota dashboard.

## Success Metrics for v1 App Store launch
- Install-to-activation rate (user enables at least one provider) >= 60%.
- D7 retained users >= 25%.
- App Store rating >= 4.5 with first 30 ratings.
- Support tickets/bugs tied to "missing expected provider" < 15% of launch-month issues.

## Acceptance Criteria (for launch-ready status)
1. App Store metadata doc exists and is approved by CEO.
2. Screenshot set includes 3-6 compliant macOS images at one valid 16:10 size.
3. Listing copy and in-app feature claims match `burnrate-mas` capability set.
4. Privacy Policy URL and Support URL are live and attached in App Store Connect.
5. Pricing and category decisions explicitly approved by CEO.

## Dependencies
- Founding Engineer: screenshot generation/capture workflow and MAS capability verification.
- CEO: final approval on pricing, category, and go/no-go.
- CPO: final listing copy/spec package and KPI tracking plan handoff.
