# UKPath — Developer Docs Index

The Developer Guide is split by **module/concern**, not kept as one large file, so anyone concentrating on a single area (e.g. "just the web build") only has to read the doc(s) relevant to that area. This index is the map — start here, then open only what you need.

See the [top-level Documentation Index](../README.md) for how the Dev docs relate to Security, Compliance, Test, and Prod.

---

## How it's organized

| Doc | Covers | Read this if you're... |
|---|---|---|
| [Architecture-and-API.md](Architecture-and-API.md) | High-level architecture, core data model, REST API surface | Building or touching the backend — this is the shared contract every platform depends on |
| [Module-Build-Notes.md](Module-Build-Notes.md) | Module A–H build notes, suggested MVP→v1 build order | Planning what to build next, regardless of platform |
| [Web/UKPath-Web-Guide.md](Web/UKPath-Web-Guide.md) | Website vs. app split, making the website feel like "the same app," SEO/Next.js notes | **Working on the website** |
| [Android/UKPath-Android-Guide.md](Android/UKPath-Android-Guide.md) | Android-specific requirements, cross-platform-without-duplication rules | **Working on the Android app** |
| [Apple/UKPath-Apple-Guide.md](Apple/UKPath-Apple-Guide.md) | iOS-specific requirements, cross-platform-without-duplication rules | **Working on the iOS app** |
| [Scaling-and-Modular-Architecture.md](Scaling-and-Modular-Architecture.md) | Scaling Node.js 10K→1 lakh users, modular-monolith module boundaries, open questions | Making structural/infra decisions |
| [Multi-Country-and-Maps.md](Multi-Country-and-Maps.md) | Multi-country config pattern, Google Maps integration | Building anything that touches country config or Maps |
| [Features/Transport-and-Reference-Data.md](Features/Transport-and-Reference-Data.md) | Transport/grocery directory, flight routes, route-planning data, AI-layer decision, daily data-refresh pipeline, taxi fares | Building the transport/logistics/reference-data features |
| [Features/Grocery-and-Delivery.md](Features/Grocery-and-Delivery.md) | Traveler-first navigation model, pre-arrival grocery ordering, Swindon hub, personal-shopper courier model | Building grocery/delivery features |
| [Features/Payments-and-Monetisation.md](Features/Payments-and-Monetisation.md) | Affiliate/partner programs (admin-only), transport-aggregator research, payment gateway (Stripe/GoCardless), KYB prerequisite | Building payments or affiliate/monetisation logic |

Both cross-platform docs (Android/Apple) share one section — "making it feel native without duplicating work" — intentionally duplicated in both files so each can be read standalone; keep the two copies identical when either changes (see "Staying in Sync" below).

---

## Where each original section number now lives

Kept the original section numbers inside each split file so old references (`Section 14`, `§28`, etc.) are still findable — just not all in one file anymore.

| Original section(s) | Now in |
|---|---|
| 1, 2, 3 | Architecture-and-API.md |
| 4, 7 | Module-Build-Notes.md |
| 5, 8.4, 8.5 | Web/UKPath-Web-Guide.md |
| 8.1, 8.3 | Android/UKPath-Android-Guide.md |
| 8.2, 8.3 | Apple/UKPath-Apple-Guide.md |
| 9, 34, 35 | Scaling-and-Modular-Architecture.md |
| 10, 11 | Multi-Country-and-Maps.md |
| 12, 14, 15, 16, 17, 19, 21 | Features/Transport-and-Reference-Data.md |
| 26, 27, 28, 29, 30 | Features/Grocery-and-Delivery.md |
| 22, 24, 31, 32, 33 | Features/Payments-and-Monetisation.md |

---

## Staying in Sync — the rule for keeping these docs from drifting

Because a module (e.g. Payments) can be described in more than one doc from a different angle (Features/Payments-and-Monetisation.md describes *what*/*why*, Security Guide describes *technical controls*, Compliance Guide describes *legal sign-off*), a change in one place must be checked against the others rather than silently duplicated:

- [ ] If you change the **data model** (Architecture-and-API.md §2), check whether [Security Guide §2](../Security/UKPath-Security-Guide.md#2-data-handling) or the [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md) reference the old shape
- [ ] If you change **module boundaries** (Scaling-and-Modular-Architecture.md §34), update the module list in this README's table above so it doesn't go stale
- [ ] If you change **one platform's requirements** (Android/Apple/Web guide), check the other two for the shared §8.3-style content that's intentionally duplicated, and check the matching platform's [Testing Guide](../Test/) for now-outdated assumptions
- [ ] If you add a **new feature** that touches money, food, or personal data, add its compliance flag to the [Compliance Guide's master table](../Compliance/UKPath-Compliance-Guide.md#master-checklist-seed-data-for-the-table-above) in the same change — don't let code and compliance tracking drift apart
- [ ] When in doubt about which doc "owns" a fact, put it in the doc whose audience acts on it (build decision → Dev docs, technical control → Security, legal sign-off → Compliance, environment/pipeline → Test/Prod) and link to it from everywhere else, rather than copying the text
