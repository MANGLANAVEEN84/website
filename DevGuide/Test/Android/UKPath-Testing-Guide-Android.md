# UKPath — Testing Guide: Android

This doc is scoped to Android only, so the Android tester/dev can work **concurrently** with whoever is testing iOS ([iOS Testing Guide](../iOS/UKPath-Testing-Guide-iOS.md)) and Web ([Web Testing Guide](../Web/UKPath-Testing-Guide-Web.md)) — all three point at the same shared test-environment backend (see [Test Environment Guide](../UKPath-Test-Environment-Guide.md#1-the-test-environment)), so none of the three blocks on the others.

See the [Documentation Index](../../README.md) for how this fits with the other docs.

---

## 1. What Backend This Runs Against

All Android testing runs against the **test environment** API (`api-test.ukpath.app` or your local Docker stack from the [Test Environment Guide §2.3](../UKPath-Test-Environment-Guide.md#23-docker-composeyml-for-the-localtest-stack)) — never production. `compliance_approvals` rows can be pre-seeded `true` in this environment purely so QA isn't blocked by real-world registrations that haven't happened yet (see [Compliance Guide](../../Compliance/UKPath-Compliance-Guide.md#how-this-interacts-with-testing)).

## 2. Getting a Build Onto Your Own Android Device (No Local Build Environment Needed)

Since local Android build tooling isn't set up, use **CodeMagic** (configured in [Test Environment Guide §4](../UKPath-Test-Environment-Guide.md#4-mobile-test-builds--codemagic)) as the build source:

1. Push the branch you want to test → CodeMagic's `android-test-build` workflow runs automatically
2. Download the resulting `.apk` artifact from the CodeMagic build page (or scan the QR code it generates)
3. On the Android phone: enable "install from unknown sources" for the browser/file app you're installing from, then install the `.apk` directly — or run `adb install app-debug.apk` over USB if you prefer
4. Confirm the app is pointed at the test API, not production (check the build's environment/secret group used)

## 3. Test Matrix — Devices & OS Versions

Per the [Android Guide §81](../../Dev/Android/UKPath-Android-Guide.md#81-android-specific-requirements-to-give-the-developer), minimum supported version is Android 9/API 28+.

| Priority | Device class | Why |
|---|---|---|
| Must test | A budget/low-end device (e.g. entry-level Samsung/Xiaomi) on Android 9–10 | Cost-conscious travellers are a real segment of users; this is where performance/memory issues surface first |
| Must test | A recent flagship on the latest Android version | Confirms nothing regresses on modern devices/gesture navigation |
| Should test | A mid-range device on Android 12–13 | Covers the largest real-world install base |

## 4. Functional Test Areas

- [ ] **Onboarding** — Google sign-in, guest mode (confirm no PII collected for guest sessions), language picker
- [ ] **Back-button behavior** — every screen must have defined behavior for the hardware/gesture back button (Android-specific; iOS has no equivalent, don't assume parity)
- [ ] **Deep linking / App Links** — affiliate redirect links and website→app handoff open the app correctly, not a browser
- [ ] **Push notifications** — Firebase Cloud Messaging delivers and displays correctly, including when the app is backgrounded/killed
- [ ] **Offline behavior** — Emergency module's offline-cached contacts load with no network connection (per [Module-Build-Notes.md](../../Dev/Module-Build-Notes.md#4-module-by-module-build-notes))
- [ ] **Each module's happy path** — Food/Grocery search, Itinerary templates, SIM comparison, Money deep-links, Writing templates, Emergency contacts
- [ ] **Checkout flows** (grocery catalogue + personal-shopper) — confirm the [compliance gate](../../Compliance/UKPath-Compliance-Guide.md#code-enforced-compliance-gate) correctly blocks checkout when required `compliance_approvals` rows are `false`, and correctly allows it when seeded `true` in test

## 5. Non-Functional Checks

- [ ] Cold start under ~2 seconds on the mid-range test device (target from [Android Guide §8.3](../../Dev/Android/UKPath-Android-Guide.md#83-making-the-app-feel-native-without-duplicating-work))
- [ ] Material Design 3 components overridden with UKPath's own brand colors/typography, not stock Material look
- [ ] No sensitive data in device logs on a release-signed build (see [Security Guide §7](../../Security/UKPath-Security-Guide.md#7-mobile-specific))

## 6. Play Store Listing Pre-Checks (Not a Launch Blocker, But Verify Early)

- [ ] Privacy policy URL reachable
- [ ] Data safety form fields match what the app actually collects
- [ ] Target audience declaration set correctly

## 7. Reporting Results

Log defects against the module they belong to (per the [modular monolith folder structure](../../Dev/Scaling-and-Modular-Architecture.md#342-the-concrete-rule-for-your-developer)), and note the CodeMagic build number tested against, so a fix can be verified against the same build lineage.
