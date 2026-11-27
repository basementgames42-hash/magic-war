# iOS builds to TestFlight, without a Mac

GitHub Actions builds the iPhone app and uploads it to TestFlight. Nobody
needs a Mac: Godot writes the Xcode project on a Linux runner, and a macOS
runner only signs and uploads it. The workflow is
`.github/workflows/ios-testflight.yml`.

**Signing is automatic.** Xcode creates and manages the distribution
certificate and the App Store provisioning profile in Apple's cloud, using
the App Store Connect API key. There are no certificate or profile files to
create, export, convert or store.

**Cost:** the Magic War repo is public, and GitHub Actions is free for
public repos, macOS runners included. If the repo is made private, macOS
minutes count 10x against the plan's monthly allowance, and the GitHub
Pages web build stops working unless the account is on a paid plan.

Everything below is done once, in a web browser. An iPhone helps for
testing, but isn't needed to set anything up.

---

## Part 1: Apple Developer account

1. **Enrol in the Apple Developer Program** at
   https://developer.apple.com/programs/enroll/ (paid yearly membership).
   - **As an individual:** quickest. Your own name is shown as the seller on
     the App Store.
   - **As an organisation:** shows the company name. It needs a legal
     business entity and a free D-U-N-S number, and takes longer to approve.
     Choose this if you and your partner run Basement Games as a company.
   - It can also be done in the Apple Developer app on an iPhone.
   - Approval can take from a few hours to a couple of days.

2. **Note your Team ID.** https://developer.apple.com/account > Membership
   details > **Team ID**: 10 letters and digits, e.g. `A1B2C3D4E5`.

3. **Register the App ID.** https://developer.apple.com/account/resources/identifiers/list
   > the **+** button > **App IDs** > **App**.
   - Description: `Magic War`
   - Bundle ID: **Explicit**, `com.basementgames.magicwar`
     (it must match `BUNDLE_ID` at the top of the workflow file; if you
     choose a different one, change it there too).
   - Capabilities: leave the defaults. Add **In-App Purchase** if it isn't
     already ticked, for the gem shop later.

4. **Accept the agreements.** https://appstoreconnect.apple.com >
   **Business** (or Agreements, Tax, and Banking): accept the Free Apps
   agreement. The Paid Apps agreement and bank/tax details are only needed
   once real in-app purchases go live.

## Part 2: The app in App Store Connect

1. https://appstoreconnect.apple.com > **Apps** > **+** > **New App**.
2. Fill in:
   - Platform: **iOS**
   - Name: `Magic War` (must be unique on the whole App Store; if it's
     taken, try something like `Magic War: Survivors`. This is only the store
     name, so the game's name inside the app is unaffected.)
   - Primary language: English
   - Bundle ID: pick `com.basementgames.magicwar` from the list
   - SKU: anything only you use, e.g. `magicwar001`
   - User access: Full Access
3. Create. TestFlight builds attach to this app.

## Part 3: The App Store Connect API key

This one key is what lets GitHub sign and upload as you.

1. https://appstoreconnect.apple.com > **Users and Access** >
   **Integrations** > **App Store Connect API** > **Team Keys**.
   (The first time, you may have to click **Request Access** and agree.)
2. **Generate API Key** (the **+** button).
   - Name: `GitHub Actions`
   - Access: **Admin**. This is required: automatic signing creates the
     cloud-managed distribution certificate, which App Manager keys can't.
3. **Download the `.p8` file.** Apple only lets you download it **once**;
   keep it somewhere safe, like a password manager. Don't commit it.
4. Note the two values on that page:
   - **Key ID** next to the key, e.g. `2X9R4HXF34`
   - **Issuer ID** at the top of the page, a long id like
     `57246542-96fe-1a63-e053-0824d011072a`

## Part 4: The private art repo

The art packs (`scenes/assets`) are licensed for use in the game, not for a
public repo, so they're git-ignored. The workflow fetches them from a
separate **private** repo.

1. Create a private repo named **`magic-war-assets`** under the
   basementgames42-hash account. Its contents are the *inside* of
   `scenes/assets` (the three pack folders at the top level).
2. Create a token that can read it:
   https://github.com/settings/personal-access-tokens/new (signed in as
   basementgames42-hash)
   - Token name: `magic-war iOS build`
   - Expiration: up to a year (put a reminder in your calendar to renew it)
   - Repository access: **Only select repositories** > `magic-war-assets`
   - Permissions > Repository > **Contents: Read-only**
   - Generate, and copy the token (it's shown once).

## Part 5: GitHub secrets

https://github.com/basementgames42-hash/magic-war/settings/secrets/actions >
**New repository secret**, once for each:

| Secret name | Value |
|---|---|
| `APPLE_TEAM_ID` | The 10-character Team ID (Part 1, step 2) |
| `APP_STORE_CONNECT_KEY_ID` | The Key ID (Part 3) |
| `APP_STORE_CONNECT_ISSUER_ID` | The Issuer ID (Part 3) |
| `APP_STORE_CONNECT_KEY_P8` | The **whole contents** of the `.p8` file: open it in Notepad and paste everything, including the `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines |
| `ASSETS_REPO_TOKEN` | The token from Part 4 |

Secrets are never shown in logs, and the workflow only runs when you start
it, so pull requests from strangers can't use them.

## Part 6: Run it

1. https://github.com/basementgames42-hash/magic-war/actions >
   **iOS build to TestFlight** > **Run workflow** > **Run workflow**.
2. It takes roughly 10-20 minutes. The first run is slower (it downloads
   Godot); later runs reuse the cached copy.
3. When it's green, Apple processes the build for 5-30 minutes. Then it
   shows in App Store Connect > your app > **TestFlight**.
4. **Testing on your iPhone:** App Store Connect > TestFlight > **Internal
   Testing** > add a group and add yourself and your partner (you must be
   users of the App Store Connect team). Install the **TestFlight** app from
   the App Store and accept the invite.

Each run uploads a new build number (the run number), so you can run it as
often as you like. To build without uploading, untick **Upload to TestFlight**
when starting it; the `.ipa` is then kept as a download on the run page.

## If a run fails

Open the failed run and the red step. Full Xcode logs are attached to the run
as **ios-logs**. Common causes:

- **"Missing GitHub secrets"**: a secret name is misspelt or missing.
- **Can't fetch the art packs**: the `magic-war-assets` repo or token
  isn't set up, or the token expired.
- **"No profiles for 'com.basementgames.magicwar' were found" / signing
  errors**: the API key isn't **Admin**, the App ID isn't registered, or
  `APPLE_TEAM_ID` is wrong.
- **"No suitable application records were found"**: the app hasn't been
  created in App Store Connect (Part 2), or its bundle ID differs.
- **"The bundle version must be higher"**: a build with that number already
  exists; just run it again.

## Still needed before the public App Store release

- **A real app icon.** `ios/app_store_icon_1024.png` is rendered from
  `icon.svg`, which is still Godot's default logo. Replace `icon.svg` with
  Magic War's own icon (1024x1024, no transparency) and regenerate the PNG.
- **Real ads and purchases**: see `docs/ios-and-ads-setup.md`
  (`autoload/ads.gd` and `autoload/store.gd` are still test placeholders).
- **Privacy details** in App Store Connect, and a privacy policy URL.
