# UKPath — Apple (iOS) Developer Guide

### Sections 8.2 & 8.3 of the Developer Guide — iOS-Specific

This doc is scoped to **iOS** so someone concentrating on Apple can build from this alone, without reading the Web/Android guides. It still depends on the shared backend contract in [Architecture-and-API.md](../Architecture-and-API.md) and the [Module Build Notes](../Module-Build-Notes.md) — those aren't duplicated here.

See the [Dev docs index](../README.md) for how this fits with the other module docs. iOS's test plan lives in [Test/iOS/UKPath-Testing-Guide-iOS.md](../../Test/iOS/UKPath-Testing-Guide-iOS.md).

---

## 8.2 iOS-specific requirements to give the developer
- [ ] Minimum supported iOS version (recommend iOS 15+ for reasonable reach without excessive legacy support cost)
- [ ] Apple Human Interface Guidelines compliance: swipe-back gestures, safe-area handling (notch/Dynamic Island), tab bar vs Android's bottom nav conventions
- [ ] Apple Sign-In is **mandatory** if you offer any other third-party login (Apple App Store rule) — already covered since you're using Google + Apple
- [ ] App Store Review Guidelines: Guideline 4.2 (minimum functionality), and clarity that Module E (Money) is informational only — reviewers are strict about anything that looks like a financial product
- [ ] Push notifications via Apple Push Notification service (APNs) — usually handled by Firebase on both platforms simultaneously
- [ ] App Tracking Transparency (ATT) prompt if you do any analytics/ad tracking

---

## 8.3 Making the app feel "native" without duplicating work

> This section is intentionally duplicated in the [Android guide](../Android/UKPath-Android-Guide.md#83-making-the-app-feel-native-without-duplicating-work) so each platform doc reads standalone. If you edit this, update the copy there too.

Give the developer this instruction explicitly, since it's the most common source of a janky cross-platform app:
- [ ] Use a cross-platform framework (React Native/Flutter) for shared logic, but **do not force identical UI on both** — navigation patterns, spacing, and system fonts should follow each platform's own convention (iOS: SF Pro, bottom tab bar, swipe gestures; Android: Roboto, may use bottom nav or drawer, hardware back button)
- [ ] Define one shared design system (colors, spacing scale, icon set, logo usage) that both platforms pull from — this is what actually creates "brand consistency," not identical pixel layouts
- [ ] Performance target: cold start under ~2 seconds on a mid-range device on both platforms

## One-page brief to hand your iOS developer

At minimum, before iOS development starts, give them:
1. This Apple Guide plus [Architecture-and-API.md](../Architecture-and-API.md) and [Module-Build-Notes.md](../Module-Build-Notes.md)
2. A design system reference (Figma file or style guide) covering colors, type, icons, logo — the same one handed to the [Android](../Android/UKPath-Android-Guide.md) and [Web](../Web/UKPath-Web-Guide.md) developers
3. Minimum iOS version and target devices (§8.2 above)
4. A list of which content is shared across app + website via the API vs. platform-specific
5. Legal sign-off confirming Module E's information-only status — see the [Compliance Guide](../../Compliance/UKPath-Compliance-Guide.md)
