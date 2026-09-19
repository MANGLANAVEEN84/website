# UKPath — Android Developer Guide

### Sections 8.1 & 8.3 of the Developer Guide — Android-Specific

This doc is scoped to **Android** so someone concentrating on Android can build from this alone, without reading the Web/Apple guides. It still depends on the shared backend contract in [Architecture-and-API.md](../Architecture-and-API.md) and the [Module Build Notes](../Module-Build-Notes.md) — those aren't duplicated here.

See the [Dev docs index](../README.md) for how this fits with the other module docs. Android's test plan lives in [Test/Android/UKPath-Testing-Guide-Android.md](../../Test/Android/UKPath-Testing-Guide-Android.md).

---

## 8.1 Android-specific requirements to give the developer
- [ ] Minimum supported Android version (recommend Android 9/API 28+ to cover most users without excluding older budget phones common with some visitors)
- [ ] Target devices: confirm if you need to support low-end/budget phones (common for cost-conscious travellers) — affects performance budget, image sizes, offline caching
- [ ] Material Design 3 components where sensible, but overridden with your own brand colors/typography — don't ship stock Material look
- [ ] Back-button behavior (Android has a hardware/gesture back button — every screen needs defined back behavior, unlike iOS)
- [ ] Google Play Store listing requirements: privacy policy URL, data safety form, target audience declaration
- [ ] Push notification setup via Firebase Cloud Messaging (FCM)
- [ ] Deep linking / App Links config (for affiliate redirects and website→app handoff)

---

## 8.3 Making the app feel "native" without duplicating work

> This section is intentionally duplicated in the [Apple guide](../Apple/UKPath-Apple-Guide.md#83-making-the-app-feel-native-without-duplicating-work) so each platform doc reads standalone. If you edit this, update the copy there too.

Give the developer this instruction explicitly, since it's the most common source of a janky cross-platform app:
- [ ] Use a cross-platform framework (React Native/Flutter) for shared logic, but **do not force identical UI on both** — navigation patterns, spacing, and system fonts should follow each platform's own convention (iOS: SF Pro, bottom tab bar, swipe gestures; Android: Roboto, may use bottom nav or drawer, hardware back button)
- [ ] Define one shared design system (colors, spacing scale, icon set, logo usage) that both platforms pull from — this is what actually creates "brand consistency," not identical pixel layouts
- [ ] Performance target: cold start under ~2 seconds on a mid-range device on both platforms

## One-page brief to hand your Android developer

At minimum, before Android development starts, give them:
1. This Android Guide plus [Architecture-and-API.md](../Architecture-and-API.md) and [Module-Build-Notes.md](../Module-Build-Notes.md)
2. A design system reference (Figma file or style guide) covering colors, type, icons, logo — the same one handed to the [Apple](../Apple/UKPath-Apple-Guide.md) and [Web](../Web/UKPath-Web-Guide.md) developers
3. Minimum Android OS version and target devices (§8.1 above)
4. A list of which content is shared across app + website via the API vs. platform-specific
5. Legal sign-off confirming Module E's information-only status — see the [Compliance Guide](../../Compliance/UKPath-Compliance-Guide.md)
