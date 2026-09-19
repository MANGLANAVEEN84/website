# UKPath — Multi-Country Support & Google Maps Integration

### Sections 10–11 of the Developer Guide

See the [Dev docs index](README.md) for how this fits with the other module docs.

---

## 10. Multi-Country Support (Build for UK, Structure for Everywhere)

Give the developer this instruction explicitly: **never hardcode "UK" in the code.** Every country-specific value — emergency numbers, grocery chains, transport apps, SIM providers, currency — lives in configuration, not in logic.

**Recommended structure — a `countries` table in the database (not a static file), so you can flip a country on without redeploying:**

```json
{
  "UK": {
    "enabled": true,
    "currency": "GBP",
    "display_name": "United Kingdom"
  },
  "IN": { "enabled": false, "currency": "INR", "display_name": "India" },
  "US": { "enabled": false, "currency": "USD", "display_name": "United States" },
  "CN": { "enabled": false, "currency": "CNY", "display_name": "China" }
}
```

- [ ] The country selector on the front page shows **all** countries, but ones with `enabled: false` show as "coming soon" (greyed out, non-clickable) rather than being hidden — this is what lets you demo the full vision to investors/users while only actually operating in the UK
- [ ] Every content table from [Architecture-and-API.md §2](Architecture-and-API.md#2-core-data-model) (`listings`, `emergency_contacts`, `templates`) gets a `country_code` column from day one, even though only `UK` rows exist right now — retrofitting this column later means touching every table and every query
- [ ] SIM providers, grocery chains, and transport apps ([Features/Transport-and-Reference-Data.md](Features/Transport-and-Reference-Data.md)) are just rows in `listings` tagged `country_code: 'UK'` — enabling India later is a content/data task, not a code change
- [ ] Emergency numbers (police, embassy, etc.) are the one place to double-check per country before ever flipping the flag — these carry real safety weight if wrong

---

## 11. Google Maps Integration

- **Places API** — live restaurant/grocery/SIM shop lookup near the user, rather than a hardcoded list that goes stale
- **Directions API** — "how do I get there" inside the Local Travel and Itinerary modules
- **Maps SDK** (JavaScript for website, native iOS/Android SDKs for the app) — for embedding the actual map view

**Cost note:** Google gives a recurring monthly free credit that comfortably covers low-volume early usage. As you scale toward 1 lakh users, Maps API calls become a real line item — cache Places results server-side (e.g. refresh listings once every 24 hours rather than calling live on every user search) to keep this cost under control. See [Features/Transport-and-Reference-Data.md §17](Features/Transport-and-Reference-Data.md#17-daily-data-refresh-pipeline-keeping-static-data-current) for the corrected, legally-compliant refresh pattern.
