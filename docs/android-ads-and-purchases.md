# Android: real ads and in-app purchases

Where things stand, and what is left before Magic War can earn on Google Play.

## What is done (in the code)

- **Ads** (`autoload/ads.gd`) use the AdMob plugin (`addons/AdmobPlugin`, v7.0).
  At startup: Google's consent form for EU/UK players, then AdMob starts and
  two rewarded ads are loaded ahead. The reward is only given when AdMob says
  the ad was watched. Game sound is muted while an ad plays.
- **Purchases** (`autoload/store.gd`) use the official Google Play Billing
  plugin (`addons/GodotGooglePlayBilling`, v3.3.0, Billing Library 9.1).
  Each purchase is checked (paid, for this app, signed by Google), granted
  once (its token is saved), then confirmed with Play. Interrupted and
  slow-payment purchases are finished at the next start.
- **Shop** shows the store's own prices and has a **Restore Purchases** button.
- **Settings** shows **Privacy Options** for players who saw the consent form.
- **Editor / desktop debug builds** keep the fake TEST ad and TEST checkout.
  **The Web build** has no ads and no purchases.
- **Android export preset** "Android" (package `com.basementgames.magicwar`,
  target API 36, Gradle build).

## Android tools on this PC

Installed under `D:\Godot\android-tools` (Java 17, Android SDK 35, NDK r28b) and
set in Godot's Editor Settings (Export > Android). The Godot Android templates
are installed too.

Build a test APK (Google's test ads; purchases need Play, see below):

```powershell
$env:JAVA_HOME = "D:\Godot\android-tools\jdk17"
& "D:\Godot\Godot.exe" --headless --path . --export-debug "Android" "build/android/MagicWar-debug.apk"
```

Install it on a phone with USB debugging on:

```powershell
& "D:\Godot\android-tools\sdk\platform-tools\adb.exe" install -r build\android\MagicWar-debug.apk
```

## What you need to do

1. **Google Play Console** (one-time $25): create the app with package name
   `com.basementgames.magicwar`. Set up a payments profile.
2. **Create the 4 in-app products** (Monetize > Products > In-app products),
   with exactly these ids, and activate them:
   - `gems_100`, `gems_550`, `gems_1200` (the game consumes them, so they can be bought again)
   - `unlock_all`
3. **Licence key**: Monetize with Play > Monetization setup > Licensing. Paste
   it into `PLAY_LICENSE_KEY` in `autoload/store.gd`. Release builds refuse
   purchases until it is set.
4. **AdMob**: create an Android app and one **Rewarded** ad unit. Put the app
   id (`ca-app-pub-...~...`) in `addons/AdmobPlugin/android_export.cfg` under
   `[Release]` and set `is_real=true`. Put the ad unit id
   (`ca-app-pub-.../...`) in `REAL_ANDROID_REWARDED_ID` in `autoload/ads.gd`.
   Never tap your own real ads: it can get the AdMob account banned.
5. **Consent form**: in AdMob > Privacy & messaging, create a GDPR message
   (EU/UK). Without it the consent form never shows.
6. **Release signing key**: an upload keystore for Play. Claude can make it;
   **back it up somewhere safe**, because a lost key means no more updates.
   Keystores are git-ignored on purpose.
7. **Store listing paperwork**: privacy policy URL, Data safety form (declare
   what AdMob collects: device / advertising ID, usage and diagnostics),
   content rating, target audience (not children), and `app-ads.txt` on your
   developer website.

## Testing purchases

Google Play Billing only works in builds installed **from Google Play**:

1. Upload a release `.aab` to the **Internal testing** track.
2. Add your Google account under Settings > **License testing**.
3. Install from the internal testing link. Test cards ("always approves" /
   "always declines" / "slow") charge nothing.
4. Check: buying gems, cancelling, a slow card (pending, then granted later),
   Unlock Everything, reinstalling and pressing Restore Purchases.

## Still to do

- iOS: the AdMob plugin also covers iOS; purchases need the StoreKit 2 plugin
  and the TestFlight workflow updated.
- Optional server check of purchases before launch (Cloudflare Worker).
- Refunds are not taken back in the game (needs the server check).
