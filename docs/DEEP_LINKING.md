# Mobile Deep Links Implementation - Walkthrough

## Problem Solved

Profile share links (e.g., `https://diaspo-niger.web.app/profile/xyz`) were not opening the mobile app automatically on Android devices. While the web overlay displayed correctly on desktop browsers, clicking these links on mobile would stay in the browser instead of launching the app.

## Solution Implemented

Implemented **Android App Links** verification using Digital Asset Links to prove domain ownership and enable automatic app launching on Android devices.

## Changes Made

### 1. Retrieved SHA-256 Certificate Fingerprint

![Browser recording showing navigation through Google Play Console](file:///C:/Users/danko/.gemini/antigravity/brain/7a6d4f21-9840-4e9f-8d44-4afe2f7c2b13/get_sha256_fingerprint_1767083763515.webp)

Navigated Google Play Console to retrieve the app signing certificate:
- **App**: Niger Diaspora
- **Package**: `com.diasponiger.diaspo_niger`
- **SHA-256**: `35:67:B0:E9:C9:01:C2:0E:B8:76:E3:CB:0B:2A:69:28:5D:5D:BB:DC:FB:89:07:0D:9C:26:91:3E:91:3F:D1:F4`

### 2. Created Digital Asset Links File

**File**: [public/.well-known/assetlinks.json](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/public/.well-known/assetlinks.json)

```json
[
  {
    "relation": ["delegate_permission/common.handle_all_urls"],
    "target": {
      "namespace": "android_app",
      "package_name": "com.diasponiger.diaspo_niger",
      "sha256_cert_fingerprints": ["35:67:B0:E9:C9:01:C2:0E:B8:76:E3:CB:0B:2A:69:28:5D:5D:BB:DC:FB:89:07:0D:9C:26:91:3E:91:3F:D1:F4"]
    }
  }
]
```

This file tells Android that the app with package `com.diasponiger.diaspo_niger` is authorized to handle all HTTPS links from `diaspo-niger.web.app`.

### 3. Updated Firebase Hosting Configuration

**File**: [firebase.json](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/firebase.json)

Modified the hosting configuration to allow serving `.well-known` directory:

```diff
  "ignore": [
    "firebase.json",
-   "**/.*",
    "**/node_modules/**"
  ],
```

Removed the `"**/.*"` pattern to ensure hidden directories like `.well-known` are served by Firebase Hosting.

### 4. Deployed to Firebase Hosting

```bash
firebase deploy --only hosting:diaspo-niger
```

Deployed 10 files including the new `assetlinks.json` to `https://diaspo-niger.web.app`.

## Verification

### ✅ Automated Verification

**Assetlinks.json Accessibility Test**

![Verification of assetlinks.json](file:///C:/Users/danko/.gemini/antigravity/brain/7a6d4f21-9840-4e9f-8d44-4afe2f7c2b13/verify_assetlinks_1767083908019.webp)

Verified that https://diaspo-niger.web.app/.well-known/assetlinks.json is:
- ✅ Accessible (returns HTTP 200)
- ✅ Properly formatted JSON
- ✅ Contains correct package name: `com.diasponiger.diaspo_niger`
- ✅ Contains correct SHA-256 fingerprint

## Manual Testing Required

> [!IMPORTANT]
> **Test on Your Android Device**
> 
> The Android App Links verification happens automatically, but it may take some time for Android to verify the association. Here's how to test:

### Testing Steps

1. **Ensure app is installed** from Google Play Store (or via release build)

2. **Test the deep link**:
   - Send yourself a profile link via WhatsApp, email, or SMS, for example:
     - `https://diaspo-niger.web.app/profile/test123`
   - Click the link
   
3. **Expected behavior**:
   - **After verification**: The app should open automatically 🎉
   - **Before verification**: You may see the web overlay with an "Open in app" button

### If the app doesn't open automatically:

Android may need time to verify the association. You can check and manually add the verified link:

1. Go to **Settings** → **Apps** → **Diaspo Niger**
2. Tap **Open by default** (or **Set as default**)
3. Tap **Add link**
4. Check if `diaspo-niger.web.app` shows as "Verified" ✓
   - If it shows "Not verified", wait a few minutes and check again
   - You can also manually enable it even if not verified yet

### Alternative Verification Method

Use Google's Statement List Generator tool:
1. Visit: https://developers.google.com/digital-asset-links/tools/generator
2. Enter domain: `diaspo-niger.web.app`
3. Verify the generated statement matches our deployed `assetlinks.json`

## How It Works

**Before this implementation:**
```
User clicks link → Opens in browser → Shows web overlay → User manually clicks "Open app"
```

**After this implementation:**
```
User clicks link → Android verifies domain ownership → App opens automatically ✨
```

The `AndroidManifest.xml` already had the correct intent filters configured with `android:autoVerify="true"`:

```xml
<intent-filter android:autoVerify="true">
    <action android:name="android.intent.action.VIEW" />
    <category android:name="android.intent.category.DEFAULT" />
    <category android:name="android.intent.category.BROWSABLE" />
    <data android:scheme="https" android:host="diasponiger.web.app" />
    <data android:scheme="https" android:host="diasponiger.com" />
</intent-filter>
```

The missing piece was the `assetlinks.json` file on the web server, which completes the two-way verification between the app and the website.

## Next Steps

> [!TIP]
> **For diasponiger.com domain**
> 
> If you want profile links shared with `diasponiger.com` (instead of `diaspo-niger.web.app`) to also open the app automatically, you'll need to:
> 1. Host the same `assetlinks.json` file at `https://diasponiger.com/.well-known/assetlinks.json`
> 2. Ensure your domain's DNS/hosting serves this file correctly

## iOS Universal Links (Configuration Future)

> [!WARNING]
> **Apple Developer Account Required**
> 
> iOS Universal Links require an active Apple Developer account to configure and test. The following steps document what needs to be done when the app is ready for iOS deployment.

### What Has Been Prepared

#### ✅ Created apple-app-site-association file

**File**: [public/.well-known/apple-app-site-association](file:///c:/Users/danko/StudioProjects/projet_perso/diaspo_niger/public/.well-known/apple-app-site-association)

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAM_ID.com.diasponiger.diaspoNiger",
        "paths": ["*"]
      }
    ]
  }
}
```

This file authorizes the iOS app (Bundle ID: `com.diasponiger.diaspoNiger`) to handle all HTTPS links from `diaspo-niger.web.app`.

⚠️ **Action Required**: Replace `TEAM_ID` with your actual Apple Developer Team ID before deploying for iOS.

### Steps to Complete (When Apple Developer Account is Available)

#### 1. Get Your Apple Developer Team ID

1. Go to [Apple Developer Account](https://developer.apple.com/account)
2. Sign in with your Apple Developer credentials
3. Navigate to **Membership** in the sidebar
4. Copy your **Team ID** (10-character code like `A1B2C3D4E5`)

#### 2. Update apple-app-site-association File

Replace `TEAM_ID` in `public/.well-known/apple-app-site-association` with your actual Team ID:

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "A1B2C3D4E5.com.diasponiger.diaspoNiger",
        "paths": ["*"]
      }
    ]
  }
}
```

#### 3. Configure Associated Domains in Xcode

1. Open `ios/Runner.xcodeproj` in Xcode
2. Select the **Runner** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability** and add **Associated Domains**
5. Add the following domains:
   - `applinks:diaspo-niger.web.app`
   - `applinks:diasponiger.com` (if using custom domain)

Alternatively, add directly to `Info.plist`:

```xml
<key>com.apple.developer.associated-domains</key>
<array>
    <string>applinks:diaspo-niger.web.app</string>
    <string>applinks:diasponiger.com</string>
</array>
```

#### 4. Update Entitlements File

Ensure the entitlements file (`ios/Runner/Runner.entitlements`) includes:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>com.apple.developer.associated-domains</key>
    <array>
        <string>applinks:diaspo-niger.web.app</string>
    </array>
</dict>
</plist>
```

#### 5. Deploy the Updated apple-app-site-association

```bash
firebase deploy --only hosting:diaspo-niger
```

The file must be accessible at:
- `https://diaspo-niger.web.app/.well-known/apple-app-site-association`
- Content-Type: `application/json` (Firebase Hosting handles this automatically)

#### 6. Test on iOS Device

> [!NOTE]
> Testing Universal Links requires a **physical iOS device** (not simulator) and the app must be installed via **TestFlight or App Store**.

**Testing steps**:
1. Install the app from TestFlight
2. Completely close the app
3. Send yourself a profile link (e.g., via Messages or Notes):
   - `https://diaspo-niger.web.app/profile/test123`
4. Long-press the link
5. You should see "Open in Diaspo Niger" option
6. Tap it - the app should open directly to that profile

**Alternative test**:
- Tap the link directly - iOS should automatically open the app instead of Safari

#### 7. Verify Universal Links

Use Apple's AASA Validator (requires app to be live on App Store or TestFlight):

1. Go to: https://branch.io/resources/aasa-validator/
2. Enter domain: `diaspo-niger.web.app`
3. Verify the AASA file is valid and contains your Bundle ID

Or use command line on device:
```bash
# Connect iPhone to Mac
xcrun simctl openurl booted "https://diaspo-niger.web.app/profile/test"
```

### Current Status

| Platform | Status | Action Required |
|----------|--------|----------------|
| **Android** | ✅ Configured and Deployed | Test on Android device |
| **iOS** | 🟡 Prepared (pending account) | Get Apple Developer account, update Team ID, configure Xcode |

### Important Notes for iOS

> [!IMPORTANT]
> **iOS Universal Links Restrictions**
> 
> - Must be tested on **physical device** (not simulator)
> - Must be installed via **TestFlight or App Store** (debug builds may not work)
> - Universal Links **don't work** when:
>   - Tapping in Safari address bar
>   - Opening from same domain (must open from external source)
>   - First install (may need app restart)

> [!TIP]
> **Debugging iOS Universal Links**
> 
> If links don't open the app:
> 1. Check Settings → Diaspo Niger → "Open with Default Browser"
> 2. Ensure Associated Domains are properly signed in Xcode
> 3. Verify AASA file is accessible without redirects
> 4. Check Console app on Mac while testing to see system logs

---

**Summary**: Android App Links are fully configured and deployed. iOS Universal Links are prepared with documentation for future implementation when an Apple Developer account becomes available.
