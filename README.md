# MOM Wealth mobile app (Flutter)

iOS and Android app for MOM Wealth members. It runs on the existing Firebase project `mom-wealth`
(us-central1) and the same backend functions as the member web portal and admin dashboard.

## What's in it
- Onboarding, sign up / sign in / password reset
- Home: total savings, quick actions, recent activity
- Savings plans: create, pay in with Squad, withdraw
- Group savings and Ajo/Esusu circles: create, join by code, contribute, payout bank, leave
- Loans: apply, reply to info requests, repayment schedule
- Profile: details, virtual account, history, withdrawals, privacy policy, sign out, delete account

Money is handled in kobo everywhere. The app never credits anything itself: every payment is
verified with Squad by the backend before a balance changes.

## How payments return to the app
1. The app calls `initiateSavingsPayment` with `returnTo: "app"` and opens Squad checkout in an
   in-app browser.
2. After payment Squad redirects to `member-portal/payment-complete.html`, which forwards to
   `momwealth://payment?ref=...`.
3. The app closes the browser and asks `confirmSavingsPayment` to verify. It also re-checks when the
   app comes back to the foreground and polls for up to 3 minutes. The Squad webhook credits the
   payment even if the member never returns.

## Project layout
```
lib/
  main.dart              start-up, deep links, auth gate
  firebase_options.dart  Firebase app IDs (iOS values come from GoogleService-Info.plist)
  theme.dart format.dart models.dart widgets.dart activity.dart
  services/session.dart  live Firestore data for the signed-in member
  services/api.dart      callable functions
  screens/               onboarding, auth, shell (tabs), home, savings, payment, withdraw,
                         history, loans, groups, profile
tool/configure_platforms.sh   creates ios/ and android/ and applies bundle IDs, link scheme, icons
.github/workflows/            checks.yml, platforms.yml, testflight.yml
```

## Identifiers
| | Value |
|---|---|
| iOS bundle ID | `com.momrehoboth.momwealth` |
| Android application ID | `com.mycompany.momwealth` (matches the Android app already in Firebase) |
| Return link | `momwealth://payment` |
| Minimum OS | iOS 15, Android 7 (API 24) |

## Building without a Mac (GitHub Actions)
1. **Checks** runs on every push: analyze, tests, Android debug APK (downloadable from the run).
2. **Generate platforms** (run once by hand): creates `ios/` and `android/`, applies the settings
   above, generates icons and splash screen, and commits them.
3. **TestFlight** (run by hand): builds on a GitHub macOS machine, signs automatically with the
   App Store Connect API key and uploads. The build number is the run number + 100.

Repository secrets (Settings > Secrets and variables > Actions):

| Secret | Where it comes from |
|---|---|
| `APPLE_TEAM_ID` | developer.apple.com > Account > Membership details > Team ID |
| `ASC_KEY_ID` | App Store Connect > Users and Access > Integrations > App Store Connect API |
| `ASC_ISSUER_ID` | same page, shown above the key list |
| `ASC_KEY_P8` | full text of the downloaded `AuthKey_XXXXXXXX.p8` (key role: **Admin**) |

The key needs the Admin role because automatic signing creates the distribution certificate and
provisioning profile on Apple's side.

## Building on a Mac (for whoever takes over)
```
flutter pub get
open ios/Runner.xcworkspace      # set your team under Signing & Capabilities
flutter run                      # or: flutter build ipa
```
Android release builds need an upload keystore; add it under `android/` with a `key.properties`
file (both are git-ignored).

## Backend changes this app relies on
- `deleteMyAccount` callable (Apple requires in-app account deletion)
- `initiateSavingsPayment` accepts `returnTo: "app"`; `MEMBER_PORTAL_URL` must be set so the callback
  points at the deployed `payment-complete.html`
