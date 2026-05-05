# burnrate-mas App Store Screenshots

5 screenshots for the Mac App Store submission of `burnrate-mas`.

## Specifications

| Property | Value |
|---|---|
| Dimensions | 1280×800 px (16:10 — valid Apple macOS screenshot family) |
| Format | PNG |
| Build | `burnrate-mas` (MAS-sandbox build) in demo mode |

Other valid App Store sizes: `1440x900`, `2560x1600`, `2880x1800` (all 16:10).

## Files

| File | Content | Shows |
|---|---|---|
| `01-dashboard-dark.png` | Main dashboard, dark theme, 4 active providers | Claude, Gemini, Copilot, Kimi with quota bars |
| `02-dashboard-light.png` | Main dashboard, light theme | Same layout, light mode |
| `03-critical-alert.png` | Near-depleted quota state | Red/critical health indicator |
| `04-settings.png` | Settings panel | Provider toggle list |
| `05-burn-rate.png` | Burn-rate pace warning active | Warning state with threshold |

## MAS Provider Note

Screenshots were captured in demo mode using `BURNRATE_DEMO=1`. The demo hero set
includes "Kimi" which is **not available in the MAS build**. Before final App Store
submission, update `DemoProvider.createHeroSet()` to replace the Kimi provider with
an MAS-available provider (e.g. Bedrock or MiniMax), then recapture:

```swift
// In Sources/Infrastructure/Demo/DemoProvider.swift
// Replace the Kimi entry with an MAS-supported provider:
DemoProvider(
    id: "bedrock",
    name: "AWS Bedrock",
    iconName: "cloud",
    quotas: [
        UsageQuota(percentRemaining: 5, quotaType: .session, providerId: "bedrock")
    ]
)
```

## Regenerating Screenshots

Run from repo root after building `burnrate-mas`:

```bash
# Build the MAS target first
tuist generate && tuist build burnrate-mas

# Run the capture script
./scripts/capture-mas-screenshots.sh
```

Or capture manually:
1. Launch with demo mode: `BURNRATE_DEMO=1 open -a path/to/burnrate-mas.app`
2. Cycle through UI states (dark, light, critical, settings, burn-rate warning)
3. Capture each with: `screencapture -R "1280,0,1280,800" -x docs/screenshots/mas/01-dashboard-dark.png`
4. Verify dimensions: `sips -g pixelWidth -g pixelHeight docs/screenshots/mas/*.png`

See also: `docs/MAS_CAPABILITY_TABLE.md` for the full MAS vs non-MAS feature breakdown.
