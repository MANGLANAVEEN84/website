# UKPath — Testing Guide: iOS

This doc is scoped to iOS only, so it can run **concurrently** with [Android testing](UKPath-Testing-Guide-Android.md) and [Web testing](UKPath-Testing-Guide-Web.md) — all three share the same test-environment backend (see [Deployment Guide](../UKPath-Deployment-Guide.md#1-environments--two-not-one)) and don't block each other.

See the [Documentation Index](../README.md) for how this fits with the other docs.

---

## 1. What Backend This Runs Against

iOS testing runs against the **test environment** API, same as Android — never production. See [Compliance Guide](../UKPath-Compliance-Guide.md#how-this-interacts-with-testing) for why `compliance_approvals` can be pre-seeded in this environment only.

## 2. Getting a Build Onto a Real iPhone Without a Local Mac

iOS builds require a Mac + Xcode locally, which is exactly what **CodeMagic** solves — it builds and code-signs the `.ipa` in the cloud (see [Deployment Guide §4](../UKPath-Deployment-Guide.md#4-mobile-builds--why-codemagic)):

1. Push the branch to test → CodeMagic's `ios-test-build` workflow runs automatically
2. CodeMagic publishes the signed build to **TestFlight** (Apple's required distribution path for anything outside the App Store, short of a paid enterprise certificate — there is no "just download the .ipa and side-load it" path on iOS the way there is on Android)
3. On the test iPhone: install the **TestFlight** app from the App Store, accept the test invite (email or public link from CodeMagic/App Store Connect), then install the UKPath build from within TestFlight
4. Confirm the build is pointed at the test API — check which secret group/environment the `ios-test-build` workflow used

## 3. Test Matrix — Devices & iOS Versions

Per [Developer Guide §8.2](../UKPath-Developer-Guide.md#82-ios-specific-requirements-to-give-the-developer), minimum supported version is iOS 15+.

| Priority | Device | Why |
|---|---|---|
| Must test | An iPhone with a notch or Dynamic Island (e.g. iPhone 14/15) on the latest iOS | Safe-area handling is the most common iOS-specific layout bug |
| Must test | An older supported device on iOS 15–16 | Confirms minimum-version support actually works, not just the newest OS |
| Should test | iPad, if the app is expected to run there at all | Confirm layout doesn't break even if iPad isn't an explicit target |

## 4. Functional Test Areas

- [ ] **Onboarding** — Apple Sign-In (mandatory per App Store rule since Google sign-in is also offered), Google sign-in, guest mode
- [ ] **Swipe-back gesture** and safe-area handling around the notch/Dynamic Island/home indicator — per Apple Human Interface Guidelines, distinct from Android's back-button model, don't assume shared code produces correct behavior here
- [ ] **Tab bar navigation** conventions vs. Android's bottom nav/drawer — confirm the iOS build follows iOS convention, not a copy-pasted Android layout
- [ ] **Push notifications via APNs** (usually routed through Firebase on both platforms, but verify delivery specifically on iOS, since the certificate/entitlement setup differs from Android's FCM)
- [ ] **App Tracking Transparency (ATT) prompt** appears correctly if any analytics/ad tracking is used — iOS-only requirement
- [ ] **Offline Emergency module** loads with no network connection
- [ ] **Each module's happy path**, same list as the Android guide — Food/Grocery, Itinerary, SIM, Money deep-links, Writing templates, Emergency
- [ ] **Checkout flows** — confirm the [compliance gate](../UKPath-Compliance-Guide.md#code-enforced-compliance-gate) behaves identically to Android (this logic is server-side, so it should be, but verify the iOS client handles the `503` "not yet available" response gracefully rather than showing a raw error)

## 5. App Store Review Pre-Checks (Verify Early, Not Just Before Submission)

Per [Developer Guide §8.2](../UKPath-Developer-Guide.md#82-ios-specific-requirements-to-give-the-developer):
- [ ] Guideline 4.2 (minimum functionality) — confirm the app doesn't read as a thin wrapper
- [ ] Money module reads clearly as **informational only** to a reviewer — App Store reviewers are strict about anything resembling a financial product; test this by having someone unfamiliar with the app review that screen specifically

## 6. Non-Functional Checks

- [ ] Cold start under ~2 seconds on the mid-range/older test device
- [ ] SF Pro font and iOS-native spacing/iconography used, not a reused Android layout (see [Developer Guide §8.3](../UKPath-Developer-Guide.md#83-making-the-app-feel-native-on-both-without-duplicating-work))
- [ ] No sensitive data in device logs on a release-signed build (see [Security Guide §7](../UKPath-Security-Guide.md#7-mobile-specific))

## 7. Reporting Results

Log defects against the module they belong to, and record the CodeMagic build number and TestFlight version tested, so a fix can be verified against the same build lineage — same convention as the [Android Testing Guide](UKPath-Testing-Guide-Android.md#7-reporting-results).
