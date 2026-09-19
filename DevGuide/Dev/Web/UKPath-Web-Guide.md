# UKPath — Web Developer Guide

### Sections 5, 8.4 & 8.5 of the Developer Guide — Website-Specific

This doc is scoped to the **website** so someone concentrating on web can build from this alone, without reading the Android/Apple guides. It still depends on the shared backend contract in [Architecture-and-API.md](../Architecture-and-API.md) and the [Module Build Notes](../Module-Build-Notes.md) — those aren't duplicated here.

See the [Dev docs index](../README.md) for how this fits with the other module docs. The website's test plan lives in [Test/Web/UKPath-Testing-Guide-Web.md](../../Test/Web/UKPath-Testing-Guide-Web.md).

---

## 5. Website vs. App Split

| Function | Website | App |
|---|---|---|
| SEO content (city guides, "how to..." articles) | ✅ Primary | Mirror only |
| Affiliate comparison pages (SIM, money) | ✅ Primary | Deep link out |
| Itinerary builder | ✅ Lite version | ✅ Full, saved |
| Emergency contacts | ✅ | ✅ Offline-cached |
| Account/login | Optional | ✅ Primary |
| Push notifications, offline maps | ❌ | ✅ |

Building the website in Next.js lets you capture organic search traffic (e.g. "SIM card for India visitors UK") before someone even downloads the app — a strong low-cost acquisition channel.

---

## 8.4 Making the website feel like "the same app"

This is a design-system problem, not a code-sharing problem — you don't need the website built in React Native.
- [ ] Give the developer a **shared design system document** first: exact colors (hex codes), logo files, typography choices, icon style, button shapes/corners, spacing rules. Both the app team and website team build from this one source.
- [ ] Website should reuse the same illustrations/icons/imagery as the app — not a different stock-photo style
- [ ] Website should be responsive and mobile-first, since a large share of visitors will land on it from a phone browser (search results, affiliate links) before ever downloading the app
- [ ] Any shared content (city guides, SIM comparisons, itinerary templates) should be pulled from the **same backend API** described in [Architecture-and-API.md §3](../Architecture-and-API.md#3-api-structure-rest) — so an update in one place shows up correctly on both. Don't let the website team maintain separate content.
- [ ] Consistent tone of voice across app and website copy — brief the developer/copywriter with a short style guide (friendly, simple English, no jargon — remember many users are first-time UK visitors)
- [ ] Website login should support the same Google/Apple sign-in so a user's saved itinerary follows them between phone and desktop

---

## 8.5 One-page brief to hand your web developer

At minimum, before web development starts, give them:
1. This Web Guide plus [Architecture-and-API.md](../Architecture-and-API.md) and [Module-Build-Notes.md](../Module-Build-Notes.md)
2. A design system reference (Figma file or style guide) covering colors, type, icons, logo — the same one handed to the [Android](../Android/UKPath-Android-Guide.md) and [Apple](../Apple/UKPath-Apple-Guide.md) developers
3. A list of which content is shared across app + website via the API vs. web-specific
4. Legal sign-off confirming Module E's information-only status (protects against FCA issues) — see the [Compliance Guide](../../Compliance/UKPath-Compliance-Guide.md)
