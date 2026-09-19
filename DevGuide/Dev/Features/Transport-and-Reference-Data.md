# UKPath — Transport & Reference Data

### Sections 12, 14, 15, 16, 17, 19 & 21 of the Developer Guide

See the [Dev docs index](../README.md) for how this fits with the other module docs.

---

## 12. UK Transport & Grocery/Food Directory (Starting Reference List)

This is a starting list for your content team to expand and verify — treat it as a draft, not a final data source. For live details (exact addresses, phone numbers, current hours), integrate the Google Places API per store rather than hardcoding contact numbers, since these vary by branch and change over time. Official top-level links are below.

### Transport apps/websites people actually use
| Service | What it's for | Official site |
|---|---|---|
| National Rail | Live train times, fee-free ticket info | nationalrail.co.uk |
| Trainline | Train + coach booking (small booking fee, very convenient) | thetrainline.com |
| TfL Go | Official London transport app — Tube, bus, Overground, live status | tfl.gov.uk |
| Citymapper | Multi-modal city routing (London, Manchester, Birmingham, etc.) | citymapper.com |
| Google Maps | General navigation, offline maps, transit directions UK-wide | maps.google.com |
| Uber | Rideshare | uber.com |

### Major UK grocery chains
| Chain | Positioning | Official site |
|---|---|---|
| Tesco | Largest by market share, broad range | tesco.com |
| Sainsbury's | Second-largest, slightly premium | sainsburys.co.uk |
| Asda | Value-focused, Yorkshire-founded | asda.com |
| Morrisons | Fresh/market-style, mid-tier pricing | morrisons.com |
| Aldi | Discounter, rapidly growing | aldi.co.uk |
| Lidl | Discounter, rapidly growing | lidl.co.uk |
| Waitrose | Premium, metro/affluent areas | waitrose.com |
| Co-op | Most locations nationally, strong in rural areas | coop.co.uk |
| Iceland | Frozen-food specialist, budget | iceland.co.uk |
| M&S Food | Premium/prepared food | marksandspencer.com |

### Food delivery platforms
| Platform | Strength | Official site |
|---|---|---|
| Deliveroo | Widest restaurant + grocery partnerships, strong in London | deliveroo.co.uk |
| Uber Eats | Best if user already has Uber; ~40 towns/cities only | ubereats.com |
| Just Eat | Broadest coverage including smaller towns | just-eat.co.uk |
| Foodhub | Budget option, 0% commission model for restaurants | foodhub.co.uk |

**How to use this in the app:** rather than manually re-typing this list into your `listings` table, most of these platforms don't offer a public API for listing their own restaurants — so your realistic play is (a) affiliate/deep-links out to these apps (see [Payments-and-Monetisation.md](Payments-and-Monetisation.md)), and (b) build your **own** curated directory of Indian restaurants, vegetarian/halal options, and Indian grocery stores using the Google Places API filtered by cuisine/category tags, since that data is what's actually missing from the market per the [Web Guide §5](../Web/UKPath-Web-Guide.md#5-website-vs-app-split).

---

## 14. India → UK Flight Routes (Reference Data for the Itinerary Module)

One correction before the data: **Bristol does not currently receive direct flights from India.** The three realistic "landing spots" for someone flying from Delhi, Mumbai, Ahmedabad, or Pune are **London Heathrow**, **London Gatwick**, and **Manchester**. Bristol is worth keeping in your city list as an onward *destination* (reachable by train/coach from any of those three), just not as a direct arrival airport. I've built the data below around the three real landing airports.

| From (India) | Direct to UK? | Typical landing airport | Airlines | Approx. flight time |
|---|---|---|---|---|
| Delhi (DEL) | Yes, direct | Heathrow (also Manchester) | Air India, British Airways, Virgin Atlantic, IndiGo | ~9h45m |
| Mumbai (BOM) | Yes, direct | Heathrow (also Manchester) | Air India, British Airways, Virgin Atlantic | ~9h |
| Ahmedabad (AMD) | Yes, direct | Gatwick | Air India | ~10h |
| Pune (PNQ) | No — connects via Delhi or Mumbai | Heathrow or Gatwick (via connection) | Air India (with partners) | ~14–16h total |

This confirms your intuition: Delhi and Mumbai travellers are the ones most likely to land at Heathrow (or occasionally Manchester), Ahmedabad travellers reliably land at Gatwick, and Pune travellers land wherever their connecting itinerary routes them — usually Heathrow or Gatwick.

### What to show the user when they land (per airport)
This is the "what can they expect" content for Module C/H — keep it short and practical, this is exactly the anxious-first-arrival moment your app should own:

**Heathrow (LHR)**
- 5 terminals — the app should ask which terminal from the boarding pass, since onward transport pickup points differ by terminal
- UK Border Control (e-gates for eligible passport holders, staffed desks for others) → baggage claim → customs
- Onward options: Heathrow Express (fastest, priciest, into central London), Elizabeth Line/Tube (cheaper, slower), National Express coach (for destinations outside London), taxi/Uber

**Gatwick (LGW)**
- 2 terminals (North/South) — Air India's Ahmedabad route typically uses South Terminal
- Onward options: Gatwick Express (into central London, ~30 min), Southern/Thameslink rail (cheaper, more stops), coach, taxi

**Manchester (MAN)**
- 3 terminals
- Onward options: Manchester Airport station is directly under Terminals 1–2 with direct rail to Manchester city centre and onward connections across the North of England — often simpler than London for anyone headed to Scotland or the North

---

## 15. Predefined Route-Planning Data (Airport → Onward Destination)

This is the "smart but not AI" version of what you described — and it's the right call for this specific feature. Here's the structure:

**A `routes` reference table**, seeded with your common corridors:

```sql
routes
  id UUID PRIMARY KEY
  origin_airport VARCHAR       -- 'LHR', 'LGW', 'MAN'
  destination_region VARCHAR   -- 'Swindon', 'Scotland', 'Birmingham', etc.
  transport_mode VARCHAR       -- 'train', 'coach', 'car'
  estimated_minutes INT        -- rough static estimate, refreshed periodically
  notes TEXT                   -- e.g. "change at Reading"
```

Example seed rows:
| Origin | Destination | Mode | Rough time | Notes |
|---|---|---|---|---|
| LHR | Swindon | Train | ~75 min | Heathrow Express to Paddington, then GWR to Swindon |
| LHR | Edinburgh (Scotland) | Train | ~5h30m | Or a 1h20m connecting flight is often faster/cheaper |
| LHR | Bristol | Coach/Train | ~2h | National Express direct, or train via Reading |
| LGW | Bristol | Train | ~2h15m | Via Reading |
| MAN | Edinburgh | Train | ~3h | Direct service |

**How this plugs into your itinerary flow:**
1. User selects departure city in India (from the flight table in Section 14 above) → app infers likely landing airport
2. User selects their onward UK destination → app looks up the static `routes` row for a rough estimate instantly, no API call needed
3. In the background (or on a "see live details" tap), the app calls the **Google Maps Directions API** (see [Multi-Country-and-Maps.md §11](../Multi-Country-and-Maps.md#11-google-maps-integration)) for the actual current-day estimate, live disruptions, and turn-by-turn
4. Static table = instant, free, always-available fallback. Live API call = accurate, current, costs a little at scale. You get both without forcing every lookup through a paid API call.

This is genuinely the cleverer approach you were reaching for — predefined data for the common 80% of routes, live data as a refinement layer, not a replacement.

---

## 16. Should You Use AI for the Chat/Query Layer? (Direct Answer)

Your instinct — **don't make the core route/logistics answers AI-generated** — is the right one. Here's why, and where AI still earns a place:

**Keep this NOT AI (use the structured data from Sections 14–15 above instead):**
- Flight options, landing airport, onward route estimates, emergency numbers, visa/immigration facts
- Reason: an LLM can confidently state a wrong flight time, wrong airport, or wrong emergency number — that's a real-world safety and trust risk for a first-time visitor. Structured data can't "hallucinate."

**Where a light AI layer genuinely helps:**
- Open-ended questions your structured data doesn't cover: "what should I pack for December in London," "my flight got delayed, what do I do now," "how do I say this in a complaint email"
- A support chatbot that answers **from your own content** (a technique called RAG — retrieval-augmented generation) rather than from general knowledge: the AI is given your `routes`, `listings`, and `templates` data as context and asked to phrase a helpful answer, rather than inventing one

**On "Copilot" specifically:** GitHub Copilot is a coding assistant for writing code — it's not something you embed in your app for end-user chat. For a customer-facing AI chat layer, the actual options are:

| Option | Cost | Notes |
|---|---|---|
| Google Gemini API (Flash model) | Free tier with generous daily limits | Good starting point, cheapest path to "AI chat" |
| OpenAI API (gpt-4o-mini or similar small model) | Pay-as-you-go, very cheap per message | No free tier, but low cost at your scale |
| Anthropic Claude API (Haiku model) | Small free credit for new accounts, then pay-as-you-go | Cheapest Claude model, good for this kind of assisted-answer use case |

**Recommended path for launch:** a human chat widget (e.g. Tawk.to) for real support conversations, plus the structured predefined data (Sections 14–15) for logistics — and hold off on the AI layer until you have real user questions logged. Once you can see the actual questions people ask that your static data doesn't answer, that's your prompt library for a RAG-based AI layer, and by then you'll know exactly which of the three APIs above fits your budget and volume.

---

## 17. Daily Data-Refresh Pipeline (Keeping Static Data Current)

This is the piece that makes Sections 12–15 above actually trustworthy over time: a scheduled backend job that goes out, checks the real sources, and updates your database — so the "static" data is really "refreshed daily," not "written once and forgotten."

### 17.1 What needs refreshing, and how often — corrected for legal compliance

**Important correction to the previous version of this section:** Google's Maps Platform Terms of Service do **not** allow what was originally described for restaurant/grocery listings. Specifically:
- You may store a **place_id** indefinitely
- You may cache **latitude/longitude** for up to 30 days
- Everything else Google returns — **name, phone number, opening hours, rating, photos** — has **no caching exception**. Google's terms explicitly prohibit exporting, extracting, or storing this content outside of live requests to their service.

This means the "scrape it once a day, store it in our own database, serve it to users from our DB" model described earlier is **not compliant** for any data sourced from Google Places, no matter how often you refresh it — "refreshing daily" doesn't cure a caching violation, because the terms don't permit caching this content at all, refreshed or not. See Section 19 below for the corrected architecture and full legal-compliance notes. The refresh pipeline below is still the right *pattern* — it's just correctly scoped to data sources that actually permit storage (your own curated listings, TfL, National Rail), with Google Places called live at display time instead of pre-fetched into your database.

| Data | Source | Refresh frequency | Why this frequency |
|---|---|---|---|
| Restaurant/grocery listings (name, phone, hours, rating) | Google Places API | Daily | Phone numbers, hours, and open/closed status change; ratings shift gradually |
| Road closures / live disruptions | Google Directions API + TfL/National Rail status feeds | Every few hours (not just daily) | Disruptions are hour-to-hour, not day-to-day |
| Route time estimates (Heathrow→Swindon, etc.) | Google Directions API | Weekly | Typical travel times don't shift daily — refreshing weekly saves API cost with no real accuracy loss |
| SIM provider plans/prices | Manual check or provider API if available | Weekly/monthly | These change occasionally, not daily |
| Emergency numbers, visa/immigration facts | Manual review only — never automated | On your own review schedule | This is the one category where an automated overwrite is dangerous if the scraper misreads a page; a human should sign off on any change here |

### 17.2 Architecture: a scheduled worker, not a live call on every user request

```
┌─────────────────┐
│  Cron Scheduler   │   (node-cron, or a managed scheduler like
│  runs daily/hourly │    AWS EventBridge / Railway Cron)
└────────┬─────────┘
         │ triggers
         ▼
┌──────────────────────┐
│   Refresh Worker Job   │   (a Node.js script, run as a
│  (BullMQ job or plain  │    background job, NOT inside your
│   scheduled script)    │    main API request/response cycle)
└────────┬─────────────┘
         │
    ┌────┴─────┐
    ▼          ▼
┌────────┐ ┌──────────────┐
│ Google  │ │ Google Roads/ │
│ Places  │ │ Directions API │
│  API    │ │  + transit     │
│         │ │  status feeds  │
└────┬────┘ └──────┬───────┘
     │             │
     ▼             ▼
┌─────────────────────────┐
│   Diff & Update Logic     │  (compare fetched data
│                            │   against current DB row)
└────────┬──────────────────┘
         ▼
┌─────────────────────────┐
│  PostgreSQL (listings,    │
│  routes tables)           │
│  + last_refreshed_at,     │
│  + data_source columns    │
└─────────────────────────┘
```

**Critical point:** this refresh job runs on its own schedule, separate from user traffic. A user opening the app always reads the already-refreshed database — they never trigger a live Google API call themselves. This keeps your app fast and keeps your API costs predictable (you pay for N refresh calls per day, not for every user's every request).

### 17.3 Schema additions to support this

```sql
-- Add to your existing `listings` table from Architecture-and-API.md §2
ALTER TABLE listings ADD COLUMN last_refreshed_at TIMESTAMP;
ALTER TABLE listings ADD COLUMN data_source VARCHAR;        -- 'google_places', 'manual'
ALTER TABLE listings ADD COLUMN google_place_id VARCHAR;    -- so re-fetching is a direct lookup, not a fresh search
ALTER TABLE listings ADD COLUMN refresh_status ENUM('ok','stale','failed');

-- New table to log every refresh run, so you can debug failures
refresh_logs
  id UUID PRIMARY KEY
  job_type VARCHAR            -- 'listings', 'routes', 'road_status'
  started_at TIMESTAMP
  finished_at TIMESTAMP
  records_checked INT
  records_updated INT
  records_failed INT
  error_summary TEXT
```

### 17.4 The update logic itself (what the job actually does each run)

1. **Pull the list of records due for refresh** — e.g. all `listings` where `last_refreshed_at` is older than 24 hours
2. **For each record, call Google Places API using the stored `google_place_id`** (a direct lookup, not a fresh text search — cheaper and more reliable than re-searching by name every time)
3. **Diff the response against the current row**: if the phone number, hours, or open/closed status changed, update it; if nothing changed, just bump `last_refreshed_at` so you know it was checked
4. **If the API call fails or the place no longer exists** (e.g. a restaurant closed down), mark `refresh_status = 'failed'` rather than deleting the row outright — flag it for a human to review before removing it from what users see
5. **Write a summary row to `refresh_logs`** so you can see at a glance whether last night's refresh ran cleanly or had failures worth investigating

### 17.5 Road closures & live route disruptions specifically

This one is genuinely time-sensitive (not just daily), so treat it separately from the restaurant refresh job:
- [ ] A separate, more frequent job (every 1–4 hours) checks the **Google Directions API** for the routes in your `routes` table (Section 15 above) and compares current estimated time against the stored baseline — if it's significantly longer, flag that route as "disrupted" in the app rather than silently updating the baseline number
- [ ] For London-specific routes, also pull **TfL's status feed** (they publish live line/road status data) rather than relying on Google alone — it's the authoritative source for Tube/bus/road disruptions in London
- [ ] For rail routes outside London, **National Rail's live departure/disruption data** is the authoritative source, same principle
- [ ] Show disruption flags to the user as "currently disrupted, allow extra time" rather than trying to compute a precise new travel time automatically — precise rerouting during live disruptions is exactly the kind of thing that's safer to hand off to the user's own Google Maps/Citymapper app (which you already deep-link to) than to try to replicate yourself

### 17.6 Cost and rate-limiting reality check

Running Google Places lookups on a schedule (rather than per-user) is exactly what keeps this affordable at 100K users: you're paying for maybe a few thousand refresh calls a day (one per listing, on your schedule) rather than millions of live calls triggered by user traffic. Still worth building in:
- [ ] A daily API call budget/cap in the job itself, so a bug can't accidentally run up a huge bill overnight
- [ ] Alerting (even a simple Slack webhook) if `refresh_logs` shows a failure rate above some threshold, so you notice a broken job the next morning rather than a week later

---

## 19. Legal Compliance for External Data Sources — See the Compliance Guide

The full legal detail for Google Places, TfL Open Data, National Rail (Darwin), and personal-data-on-individuals concerns lives in the [Compliance Guide §2](../../Compliance/UKPath-Compliance-Guide.md#2-external-data-source-compliance), so it's tracked alongside the other legal sign-offs rather than mixed into build notes here.

**The one architectural rule that stays here, because it's a build decision, not a legal one:** store only `place_id` from Google Places long-term; call Google Places **live, at the moment a user views a listing**, for name/phone/hours/rating — never cache that content in your own database, per Google's Maps Platform Terms of Service. The daily refresh job (Section 17 above) is fine for checking a `place_id` is still valid; it must not be what populates what users see for that data.

---

## 21. UK Taxi/Private-Hire Fare Data — What's Actually Official

Following the same rule from Section 19 above: check whether an official source exists before building anything, and link out rather than scrape when it doesn't.

### 21.1 London black cabs — genuinely official, safe to build from

TfL publishes the actual regulatory tariff structure for licensed London taxis (black cabs/hackney carriages) — this is public regulatory information, not scraped private content, so it's fine to use as the basis for your own fare estimate calculator:
- **Three tariffs**: Tariff 1 (Mon–Fri, roughly 06:00–20:00, standard day rate), Tariff 2 (evenings Mon–Fri and all-day weekends, higher rate), Tariff 3 (nightly ~22:00–06:00 and public holidays, highest rate — this is your "night charges" answer)
- **Minimum fare** and per-mile/per-minute rates are published on TfL's official taxi fares page and reviewed roughly annually
- [ ] Build your calculator from TfL's published tariff table (cite TfL as the source, link to their official page for the current exact figures) — but always frame it as an **estimate**, since the actual meter accounts for real-time traffic and exact route, which your static table can't replicate
- Private-hire vehicles (minicabs) in London are **pre-agreed price, not metered** — there's no tariff table to build from; the honest answer for these is "the operator confirms the price before you travel," not a calculator

### 21.2 Outside London — no single official body, no national fare API

This is the honest limitation: outside London, taxi/private-hire licensing is handled by **individual local councils**, each of which can set its own hackney carriage tariff. There is no single national taxi fare authority or public API covering all of England/Scotland/Wales/NI.
- The one national database that does exist — **NR3S**, run by the Local Government Association/National Anti-Fraud Network — only contains licence **refusals and revocations** for safeguarding purposes. It's not a fare database and isn't a public API for app developers to query.
- [ ] For cities outside London, the right approach is exactly what you'd expect: **link out** to the official channel rather than scrape — either the local council's published tariff page (if one exists) or, more practically, the ride-hailing apps themselves (Uber, Bolt) which show a live fare estimate through their own apps before booking
- [ ] Where you're not sure whether a given council or local taxi firm's page can be used, the safe default is the same principle as Section 19: **link to it, don't scrape it** — and if a specific case is genuinely ambiguous, that's a "flag it and ask" situation rather than a "guess and proceed" one
