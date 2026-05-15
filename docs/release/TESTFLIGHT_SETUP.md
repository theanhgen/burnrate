# TestFlight Setup Guide

How to get `burnrate-mas` into TestFlight using the `App Store Release` workflow
(`.github/workflows/appstore-release.yml`).

The workflow is already implemented — this guide covers the one-time configuration
required before you can trigger it.

---

## What the workflow does

1. Updates `Info.plist` version/build from workflow inputs.
2. Strips Sparkle keys (not allowed in MAS builds).
3. Archives `burnrate-mas` scheme with manual signing.
4. Exports as signed PKG using `3rd Party Mac Developer Installer`.
5. Validates sandbox entitlement.
6. Uploads PKG to App Store Connect.
7. Distributes to the configured TestFlight beta group.
8. Optionally submits for App Store review.

Trigger: **manual only** (`workflow_dispatch` → Actions → App Store Release → Run workflow).

---

## Prerequisites

### 1. Apple Developer account

Active Apple Developer Program membership ($99/year).

### 2. App record in App Store Connect

1. Go to [App Store Connect → Apps](https://appstoreconnect.apple.com/apps).
2. Click **+** → **New App**.
3. Platform: **macOS**.
4. Bundle ID: `com.nguyentheanh.burnrate` (must be registered first in the Developer Portal).
5. Complete the form. The numeric **App ID** shown in the URL is what you need for `APP_ID`.

### 3. Register the Bundle ID

1. [Developer Portal → Identifiers](https://developer.apple.com/account/resources/identifiers/list).
2. Click **+** → **App IDs** → **App**.
3. Bundle ID: `com.nguyentheanh.burnrate` (Explicit).
4. Capabilities: enable **App Groups** → group: `group.com.nguyentheanh.burnrate`.

### 4. Create Mac App Store certificates

You need two certificates — both can be exported into a single P12.

**Certificate 1: 3rd Party Mac Developer Application**
1. [Developer Portal → Certificates → +](https://developer.apple.com/account/resources/certificates/add).
2. Select **Mac App Distribution** (under "Software").
3. Generate a CSR in Keychain Access and upload it.
4. Download and double-click the `.cer` to install it.

**Certificate 2: 3rd Party Mac Developer Installer**
1. Repeat the same steps, but select **Mac Installer Distribution**.
2. Download and install.

**Export both into one P12:**
1. Open Keychain Access → **My Certificates**.
2. Select **both** `3rd Party Mac Developer Application: ...` and `3rd Party Mac Developer Installer: ...`.
3. File → Export Items → Personal Information Exchange (.p12).
4. Set a password. This is `APPLE_MAS_CERTIFICATE_PASSWORD`.
5. Base64-encode:
   ```bash
   base64 -i path/to/mas-certs.p12 | tr -d '\n' | pbcopy
   ```
   Paste as `APPLE_MAS_CERTIFICATE_P12`.

### 5. Create a Mac App Store provisioning profile

1. [Developer Portal → Profiles → +](https://developer.apple.com/account/resources/profiles/add).
2. Select **Mac App Store Distribution**.
3. Select bundle ID `com.nguyentheanh.burnrate`.
4. Select the `3rd Party Mac Developer Application` certificate.
5. Name it (e.g., `burnrate MAS Distribution`).
6. Generate and download.

> **Note:** The CI script (`install-mas-profile.sh`) downloads and installs the profile
> automatically using the App Store Connect API. You do not need to commit the profile file.
> Just ensure it exists in the Developer Portal.

### 6. Create an App Store Connect API key

1. [App Store Connect → Users and Access → Integrations → App Store Connect API](https://appstoreconnect.apple.com/access/api).
2. Click **+** to generate a key.
3. Role: **Developer** (minimum) or **Admin**.
4. Download the `.p8` file — **you can only download once**.
5. Note the **Key ID** and **Issuer ID**.
6. Base64-encode:
   ```bash
   base64 -i AuthKey_XXXXXX.p8 | tr -d '\n' | pbcopy
   ```

### 7. Create a TestFlight external beta group

1. In App Store Connect → your app → **TestFlight** tab.
2. Under **External Testing**, click **+** to create a group.
3. Name it (e.g., `External Testers`).
4. The group ID is in the URL: `...testflight/groups/<GROUP_ID>`.
   Copy it — this is `BETA_GROUP_ID`.
5. Fill in **Test Information** (feedback email, description, What to Test) —
   required before Apple's Beta App Review will allow external distribution.

### 8. Find your Team ID

Your 10-character Apple Developer Team ID is shown in:
- [Developer Portal → Membership](https://developer.apple.com/account/#/membership/) under **Team ID**.

---

## Configure GitHub

### Secrets (Settings → Secrets and variables → Actions → Secrets)

| Secret | Where to get it |
|--------|----------------|
| `APPLE_MAS_CERTIFICATE_P12` | Base64-encoded P12 from step 4 |
| `APPLE_MAS_CERTIFICATE_PASSWORD` | Password set when exporting the P12 |
| `APP_STORE_CONNECT_API_KEY_P8` | Base64-encoded `.p8` from step 6 |
| `APP_STORE_CONNECT_KEY_ID` | Key ID from step 6 |
| `APP_STORE_CONNECT_ISSUER_ID` | Issuer ID from step 6 |

> The three `APP_STORE_CONNECT_*` secrets are shared with the Sparkle release workflow.
> If already set, you don't need to add them again.

### Variables (Settings → Secrets and variables → Actions → Variables)

| Variable | Value |
|----------|-------|
| `APP_ID` | Numeric App Store Connect app ID (from the app URL in ASC) |
| `BETA_GROUP_ID` | UUID from the TestFlight group URL |
| `DEVELOPMENT_TEAM` | Your 10-character Apple Developer Team ID |

---

## Trigger the workflow

1. Go to **Actions** → **App Store Release** → **Run workflow**.
2. Fill in:
   - **Version string**: `1.0.0`
   - **Build number**: leave blank (uses GitHub run number)
   - **What's New**: text shown to TestFlight testers
   - **Submit to App Store after TestFlight**: `false` for the first run
3. Click **Run workflow**.

The workflow takes ~15-20 minutes. On success:
- The build appears in App Store Connect → TestFlight.
- Apple performs Beta App Review (1-2 days for external groups on first submission).
- After approval, testers in the external group receive an invite.

---

## First-time TestFlight checklist

Before triggering the workflow for the first time, verify:

- [ ] App record created in App Store Connect (have `APP_ID`).
- [ ] Bundle ID registered with App Groups capability.
- [ ] Both MAS certificates installed and exported in one P12.
- [ ] MAC_APP_STORE provisioning profile exists in Developer Portal.
- [ ] TestFlight external group created (have `BETA_GROUP_ID`).
- [ ] Test Information filled in App Store Connect (required for external Beta App Review).
- [ ] All 5 GitHub secrets set.
- [ ] All 3 GitHub variables set.
- [ ] `ITSAppUsesNonExemptEncryption = false` in `Info.plist` — already set.

---

## Troubleshooting

**"No PKG file found in export output"**
The `3rd Party Mac Developer Installer` certificate is missing from the P12. Re-export
both certificates into the same P12.

**"Profile not found" / install-mas-profile.sh fails**
The MAC_APP_STORE provisioning profile is not in the Developer Portal, or the App Store
Connect API key lacks permission to read it. Check the profile exists and the key role is
Developer or Admin.

**"Sandbox entitlement missing"**
The build used the wrong scheme or entitlements file. The workflow uses `burnrate-mas` scheme
and `entitlements.mas.plist` — verify both are in place.

**Build stuck in PROCESSING**
Normal — Apple processes uploads for 5-30 minutes. The workflow waits via `--wait` flag.
If it times out, re-run the workflow — uploads that already completed won't be re-uploaded.

**Beta App Review rejected**
Common for first submissions. Ensure:
- Test Information is complete in App Store Connect.
- The app runs on a real device (demo mode must be off in the submitted build).
- No calls to private APIs.
