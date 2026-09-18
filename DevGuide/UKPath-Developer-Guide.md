# UKPath — Developer Guide
### Building the App & Companion Website for India → UK Visitors

This guide translates the UKPath product spec into a practical build plan: architecture, tech stack, data model, API surface, and a module-by-module implementation checklist for both the mobile app and the website.

---

## 1. High-Level Architecture

```
┌─────────────────┐     ┌─────────────────┐
│   Mobile App     │     │     Website      │
│ (iOS + Android)  │     │  (Marketing +     │
│ React Native /   │     │   Lite Web App)   │
│    Flutter        │     │  Next.js / React  │
└────────┬─────────┘     └────────┬─────────┘
         │                        │
         └──────────┬─────────────┘
                     │
              ┌──────▼───────┐
              │   API Layer    │
              │ (REST/GraphQL) │
              │  Node.js/NestJS│
              └──────┬───────┘
                     │
      ┌──────────────┼──────────────┐
      │              │              │
┌─────▼────┐  ┌──────▼──────┐ ┌─────▼─────┐
│ PostgreSQL│  │ Redis Cache  │ │  S3/Blob   │
│ (core DB) │  │ (sessions)   │ │  Storage   │
└──────────┘  └─────────────┘ └───────────┘
```

**Recommended stack:**
- **Mobile:** React Native (single codebase for iOS/Android) or Flutter
- **Website:** Next.js (SEO-friendly, SSR for guides/blog content)
- **Backend:** Node.js + NestJS (or Express) — REST API, JWT auth
- **Database:** PostgreSQL (structured data) + Redis (caching, sessions)
- **Auth:** Firebase Auth or Auth0 (handles Google/Apple sign-in out of the box)
- **File/Media storage:** AWS S3 or Cloudflare R2 for offline maps, guides, images
- **Hosting:** AWS/GCP for backend, Vercel/Netlify for website frontend

---

## 2. Core Data Model

Since the app stores **no sensitive personal data**, the schema stays deliberately thin.

```sql
-- Users (anonymous-first)
users
  id UUID PRIMARY KEY
  auth_provider ENUM('google','apple','guest')
  anon_id VARCHAR UNIQUE
  language_pref VARCHAR(10)
  is_india_visitor BOOLEAN DEFAULT true
  created_at TIMESTAMP

-- Itineraries
itineraries
  id UUID PRIMARY KEY
  user_id UUID REFERENCES users(id)
  duration_days INT
  city VARCHAR
  content JSONB   -- day-by-day plan
  created_at TIMESTAMP

-- Directory listings (restaurants, SIM shops, grocery, etc.)
listings
  id UUID PRIMARY KEY
  category ENUM('food','grocery','sim','transport','emergency')
  name VARCHAR
  tags TEXT[]           -- e.g. ['vegetarian','halal']
  location GEOGRAPHY(POINT)
  affiliate_link VARCHAR
  metadata JSONB

-- Emergency contacts (static reference table)
emergency_contacts
  id UUID PRIMARY KEY
  type ENUM('police','nhs','embassy','lost_passport')
  region VARCHAR
  phone VARCHAR
  notes TEXT

-- Writing templates
templates
  id UUID PRIMARY KEY
  category ENUM('email','complaint','lost_item','emergency')
  title VARCHAR
  body_template TEXT

-- Service requests (paid help: SIM setup, itinerary planning, writing help)
service_requests
  id UUID PRIMARY KEY
  user_id UUID REFERENCES users(id)
  service_type VARCHAR
  status ENUM('pending','in_progress','completed')
  fee_amount DECIMAL
  created_at TIMESTAMP
```

No table stores DOB, passport numbers, addresses, or card numbers — this keeps you outside FCA/PCI-DSS scope and simplifies GDPR compliance.

---

## 3. API Structure (REST)

```
POST   /auth/google           # Google sign-in
POST   /auth/apple            # Apple sign-in
POST   /auth/guest            # Guest session

GET    /listings?category=food&tags=vegetarian&near=lat,lng
GET    /listings/:id

GET    /itineraries/templates?days=7&city=london
POST   /itineraries            # save a custom itinerary

GET    /sim/options            # compare SIM providers
GET    /sim/guide/:provider    # activation steps

GET    /emergency/contacts?region=london
GET    /emergency/lost-passport-steps

GET    /templates?category=complaint
POST   /templates/:id/fill     # returns filled template text

POST   /service-requests       # request paid help (SIM setup, itinerary, writing)
GET    /service-requests/:id

GET    /affiliate/redirect/:partner   # tracked outbound link (Booking.com, Wise, etc.)
```

Keep the API **stateless and cache-friendly** — most of this content (listings, guides, templates) changes rarely, so cache aggressively with Redis or a CDN.

---

## 4. Module-by-Module Build Notes

**Module A — Onboarding**
- Firebase/Auth0 for Google + Apple sign-in
- "Continue as Guest" path stores only a device-generated anonymous ID
- Language picker (start with English + Hindi; expand later)

**Module B — Food & Grocery**
- Pull listings from your own curated DB, not live scraping (avoids ToS issues with Google/Yelp)
- Filter chips: vegetarian, halal, budget, near-me
- Consider a lightweight partnership feed with Zomato/JustEat for richer data

**Module C — Local Travel**
- Deep-link into TfL Go, Trainline, Uber rather than rebuilding transit routing — you're a guidance layer, not a routing engine
- Static "how the Tube/bus system works" explainer content is high value for first-time visitors

**Module D — SIM & Connectivity**
- Static comparison table (data, price, coverage) refreshed manually/quarterly
- Step-by-step activation guides per provider (Lyca, Giffgaff, EE, O2, Vodafone)

**Module E — Money (Consult-Only)**
- **Critical:** this module must only display *information* — no card issuance, top-ups, or balance display. Any of that tips you into FCA-regulated e-money territory.
- Deep-link to Wise/Revolut/Travelex for actual account setup

**Module F — Itinerary Planning**
- Start with static templated itineraries (3/7/10-day) per city
- Personalization (v2) can use simple rule-based logic before investing in ML

**Module G — Writing Help**
- Template library with fill-in-the-blank fields (hotel name, dates, issue)
- Exportable as PDF or copyable text

**Module H — Emergency & Safety**
- This is your highest-trust, lowest-monetization module — treat it as a retention/trust feature, not a revenue line
- Keep an offline-cached version (no connectivity needed) of police/NHS/embassy numbers

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

## 6. Security & Compliance Checklist

- [ ] HTTPS/TLS everywhere, HSTS enabled
- [ ] JWT with short expiry + refresh tokens
- [ ] No storage of DOB, passport, address, or card data — enforce via schema design, not just policy
- [ ] UK GDPR: privacy policy, cookie consent (website), data deletion endpoint
- [ ] Rate-limit auth and service-request endpoints
- [ ] Log affiliate redirects for revenue tracking, not user behavior profiling
- [ ] Legal review before launch to confirm no FCA registration is triggered by Module E

---

## 7. Suggested Build Order (MVP → v1)

1. **MVP (6–8 weeks):** Onboarding, static Emergency module, static Itinerary templates, affiliate links for Money/SIM
2. **v1:** Food & Grocery directory, Writing templates, SIM comparison + guides, website with SEO content
3. **v1.1:** Paid service requests (itinerary planning, writing help), premium subscription, personalized itineraries

---

## 8. What to Specify for Developers: Android, iOS & Website Parity

If you want the app to feel right on both Android and iPhone, and the website to feel like "the same product," you need to hand your developer a clear brief up front — not leave these as afterthoughts.

### 8.1 Android-specific requirements to give the developer
- [ ] Minimum supported Android version (recommend Android 9/API 28+ to cover most users without excluding older budget phones common with some visitors)
- [ ] Target devices: confirm if you need to support low-end/budget phones (common for cost-conscious travellers) — affects performance budget, image sizes, offline caching
- [ ] Material Design 3 components where sensible, but overridden with your own brand colors/typography — don't ship stock Material look
- [ ] Back-button behavior (Android has a hardware/gesture back button — every screen needs defined back behavior, unlike iOS)
- [ ] Google Play Store listing requirements: privacy policy URL, data safety form, target audience declaration
- [ ] Push notification setup via Firebase Cloud Messaging (FCM)
- [ ] Deep linking / App Links config (for affiliate redirects and website→app handoff)

### 8.2 iOS-specific requirements to give the developer
- [ ] Minimum supported iOS version (recommend iOS 15+ for reasonable reach without excessive legacy support cost)
- [ ] Apple Human Interface Guidelines compliance: swipe-back gestures, safe-area handling (notch/Dynamic Island), tab bar vs Android's bottom nav conventions
- [ ] Apple Sign-In is **mandatory** if you offer any other third-party login (Apple App Store rule) — already covered since you're using Google + Apple
- [ ] App Store Review Guidelines: Guideline 4.2 (minimum functionality), and clarity that Module E (Money) is informational only — reviewers are strict about anything that looks like a financial product
- [ ] Push notifications via Apple Push Notification service (APNs) — usually handled by Firebase on both platforms simultaneously
- [ ] App Tracking Transparency (ATT) prompt if you do any analytics/ad tracking

### 8.3 Making the app feel "native" on both without duplicating work
Give the developer this instruction explicitly, since it's the most common source of a janky cross-platform app:
- [ ] Use a cross-platform framework (React Native/Flutter) for shared logic, but **do not force identical UI on both** — navigation patterns, spacing, and system fonts should follow each platform's own convention (iOS: SF Pro, bottom tab bar, swipe gestures; Android: Roboto, may use bottom nav or drawer, hardware back button)
- [ ] Define one shared design system (colors, spacing scale, icon set, logo usage) that both platforms pull from — this is what actually creates "brand consistency," not identical pixel layouts
- [ ] Performance target: cold start under ~2 seconds on a mid-range device on both platforms

### 8.4 Making the website feel like "the same app"
This is a design-system problem, not a code-sharing problem — you don't need the website built in React Native.
- [ ] Give the developer a **shared design system document** first: exact colors (hex codes), logo files, typography choices, icon style, button shapes/corners, spacing rules. Both the app team and website team build from this one source.
- [ ] Website should reuse the same illustrations/icons/imagery as the app — not a different stock-photo style
- [ ] Website should be responsive and mobile-first, since a large share of visitors will land on it from a phone browser (search results, affiliate links) before ever downloading the app
- [ ] Any shared content (city guides, SIM comparisons, itinerary templates) should be pulled from the **same backend API** described in Section 3 — so an update in one place shows up correctly on both. Don't let the website team maintain separate content.
- [ ] Consistent tone of voice across app and website copy — brief the developer/copywriter with a short style guide (friendly, simple English, no jargon — remember many users are first-time UK visitors)
- [ ] Website login should support the same Google/Apple sign-in so a user's saved itinerary follows them between phone and desktop

### 8.5 One-page brief to hand your developer(s)
At minimum, before development starts, give them:
1. This developer guide (architecture, data model, API, modules)
2. A design system reference (Figma file or style guide) covering colors, type, icons, logo
3. Minimum OS versions and target devices for Android/iOS
4. A list of which content is shared across app + website via the API vs. platform-specific
5. Legal sign-off confirming Module E's information-only status (protects against App Store rejection and FCA issues)

---

## 9. Scaling Node.js from 10K to 1 Lakh+ Users

Don't over-engineer early — but structure the code so each stage below is an incremental change, not a rewrite.

**Stage 1 — 0 to 10K users (where you start)**
- Single Node.js instance, managed PostgreSQL, Redis for caching/sessions
- Everything in one repo, one deploy

**Stage 2 — 10K to 50K users**
- [ ] Run Node in cluster mode (PM2) or as multiple containers behind a load balancer — Node is single-threaded per process, so you scale by running more processes, not by making one process "bigger"
- [ ] Move all session state to Redis so any app instance can handle any request (stateless app servers)
- [ ] Put a CDN (Cloudflare works well and has a generous free tier) in front of static assets and cacheable API responses
- [ ] Add a job queue (BullMQ + Redis) for anything that doesn't need to happen instantly — emails, service-request notifications, report generation — so the main API stays fast
- [ ] Add a database read replica once read traffic (listings, guides, itineraries) starts outpacing writes

**Stage 3 — 50K to 1 lakh users**
- [ ] Containerize with Docker; run on a managed container platform (AWS Fargate, Google Cloud Run, or Railway's autoscaling) rather than jumping straight to Kubernetes unless you have a dedicated DevOps hire — Kubernetes adds real operational overhead that isn't justified at this scale
- [ ] Add connection pooling in front of PostgreSQL (PgBouncer) — Node apps open a lot of short-lived DB connections and Postgres has a hard connection limit
- [ ] Centralized logging and monitoring (Grafana + Prometheus, or a hosted option like Better Stack) so you can see problems before users report them
- [ ] Proper CI/CD with zero-downtime deploys (rolling restarts) and staging environment before production
- [ ] API rate limiting per user/IP to protect against abuse and runaway costs (especially on any endpoint that calls Google Maps)

**The honest takeaway:** horizontal scaling of stateless Node servers plus a solid cache layer gets you further than most people expect before the database itself becomes the bottleneck. Don't reach for microservices or Kubernetes just because "scale" is the goal — reach for them when a specific, measured bottleneck demands it.

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
- [ ] Every content table from Section 2 (`listings`, `emergency_contacts`, `templates`) gets a `country_code` column from day one, even though only `UK` rows exist right now — retrofitting this column later means touching every table and every query
- [ ] SIM providers, grocery chains, and transport apps (Section 13 below) are just rows in `listings` tagged `country_code: 'UK'` — enabling India later is a content/data task, not a code change
- [ ] Emergency numbers (police, embassy, etc.) are the one place to double-check per country before ever flipping the flag — these carry real safety weight if wrong

---

## 11. Google Maps Integration

- **Places API** — live restaurant/grocery/SIM shop lookup near the user, rather than a hardcoded list that goes stale
- **Directions API** — "how do I get there" inside the Local Travel and Itinerary modules
- **Maps SDK** (JavaScript for website, native iOS/Android SDKs for the app) — for embedding the actual map view

**Cost note:** Google gives a recurring monthly free credit that comfortably covers low-volume early usage. As you scale toward 1 lakh users, Maps API calls become a real line item — cache Places results server-side (e.g. refresh listings once every 24 hours rather than calling live on every user search) to keep this cost under control.

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

**How to use this in the app:** rather than manually re-typing this list into your `listings` table, most of these platforms don't offer a public API for listing their own restaurants — so your realistic play is (a) affiliate/deep-links out to these apps (as already planned in Section 9 monetisation), and (b) build your **own** curated directory of Indian restaurants, vegetarian/halal options, and Indian grocery stores using the Google Places API filtered by cuisine/category tags, since that data is what's actually missing from the market per Section 5.

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
1. User selects departure city in India (from the flight table in Section 14) → app infers likely landing airport
2. User selects their onward UK destination → app looks up the static `routes` row for a rough estimate instantly, no API call needed
3. In the background (or on a "see live details" tap), the app calls the **Google Maps Directions API** (Section 11) for the actual current-day estimate, live disruptions, and turn-by-turn
4. Static table = instant, free, always-available fallback. Live API call = accurate, current, costs a little at scale. You get both without forcing every lookup through a paid API call.

This is genuinely the cleverer approach you were reaching for — predefined data for the common 80% of routes, live data as a refinement layer, not a replacement.

---

## 16. Should You Use AI for the Chat/Query Layer? (Direct Answer)

Your instinct — **don't make the core route/logistics answers AI-generated** — is the right one. Here's why, and where AI still earns a place:

**Keep this NOT AI (use the structured data from Sections 14–15 instead):**
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

**Recommended path for launch:** Section 8's Tawk.to human chat widget for real support conversations, plus the structured predefined data (Sections 14–15) for logistics — and hold off on the AI layer until you have real user questions logged. Once you can see the actual questions people ask that your static data doesn't answer, that's your prompt library for a RAG-based AI layer, and by then you'll know exactly which of the three APIs above fits your budget and volume.

---

## 17. Daily Data-Refresh Pipeline (Keeping Static Data Current)

This is the piece that makes Sections 12–15 actually trustworthy over time: a scheduled backend job that goes out, checks the real sources, and updates your database — so the "static" data is really "refreshed daily," not "written once and forgotten."

### 17.1 What needs refreshing, and how often — corrected for legal compliance

**Important correction to the previous version of this section:** Google's Maps Platform Terms of Service do **not** allow what I originally described for restaurant/grocery listings. Specifically:
- You may store a **place_id** indefinitely
- You may cache **latitude/longitude** for up to 30 days
- Everything else Google returns — **name, phone number, opening hours, rating, photos** — has **no caching exception**. Google's terms explicitly prohibit exporting, extracting, or storing this content outside of live requests to their service.

This means the "scrape it once a day, store it in our own database, serve it to users from our DB" model I described earlier is **not compliant** for any data sourced from Google Places, no matter how often you refresh it — "refreshing daily" doesn't cure a caching violation, because the terms don't permit caching this content at all, refreshed or not. See Section 19 for the corrected architecture and full legal-compliance notes. The refresh pipeline below is still the right *pattern* — it's just correctly scoped to data sources that actually permit storage (your own curated listings, TfL, National Rail), with Google Places called live at display time instead of pre-fetched into your database.

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
-- Add to your existing `listings` table from Section 2
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
- [ ] A separate, more frequent job (every 1–4 hours) checks the **Google Directions API** for the routes in your `routes` table (Section 15) and compares current estimated time against the stored baseline — if it's significantly longer, flag that route as "disrupted" in the app rather than silently updating the baseline number
- [ ] For London-specific routes, also pull **TfL's status feed** (they publish live line/road status data) rather than relying on Google alone — it's the authoritative source for Tube/bus/road disruptions in London
- [ ] For rail routes outside London, **National Rail's live departure/disruption data** is the authoritative source, same principle
- [ ] Show disruption flags to the user as "currently disrupted, allow extra time" rather than trying to compute a precise new travel time automatically — precise rerouting during live disruptions is exactly the kind of thing that's safer to hand off to the user's own Google Maps/Citymapper app (which you already deep-link to) than to try to replicate yourself

### 17.6 Cost and rate-limiting reality check

Running Google Places lookups on a schedule (rather than per-user) is exactly what keeps this affordable at 100K users: you're paying for maybe a few thousand refresh calls a day (one per listing, on your schedule) rather than millions of live calls triggered by user traffic. Still worth building in:
- [ ] A daily API call budget/cap in the job itself, so a bug can't accidentally run up a huge bill overnight
- [ ] Alerting (even a simple Slack webhook) if `refresh_logs` shows a failure rate above some threshold, so you notice a broken job the next morning rather than a week later

---

## 19. Legal Compliance Checklist for Every External Data Source

You're right to flag this before building it — this is exactly the kind of thing that's cheap to get right at the design stage and expensive to fix after launch. I checked the actual current terms for each source rather than assuming. Here's where each one stands:

### 19.1 Google Places API — restricted, not "publicly available to store"

Google's Maps Platform Terms of Service are explicit: you may **not** export, extract, or scrape Google Maps content for use outside their services, and caching is prohibited **except** for two narrow exceptions:
- `place_id` → can be stored indefinitely
- Latitude/longitude → can be cached up to 30 consecutive days

**Name, address, phone number, hours, rating, reviews, photos → no caching exception at all.** They must be requested live, every time you display them, directly from Google's API — not written into your own database, not "refreshed daily," not stored even briefly beyond a single request/response cycle.

**What this means for your build:**
- [ ] Store only the `place_id` in your `listings` table (this is what your app can legally keep long-term)
- [ ] Call Google Places **live, at the moment a user views that listing**, to fetch the current name/phone/hours/rating — display it, don't save it
- [ ] Your "refresh job" from Section 17 is legally fine to run daily against Google **for the purpose of checking whether a place_id is still valid** (e.g. confirming it hasn't closed), but it can't be the mechanism that populates what users actually see — that has to be a live call
- [ ] If you want a genuinely storable, cacheable restaurant/grocery directory (which is what your daily-refresh idea actually needs to work well), look at providers built on **OpenStreetMap data with permissive storage terms** — Geoapify and LocationIQ both explicitly allow caching, storing, and redistributing results, unlike Google. This is worth strongly considering for exactly the use case you described.
- [ ] Every screen showing Google Places data needs the Google logo/attribution per their display guidelines — this is a hard requirement, not optional styling

### 19.2 TfL Open Data — genuinely open, registration required

TfL explicitly encourages third-party apps to use their open data for building their own software and services, including presenting travel information in innovative ways — commercial use included. But it's not a free-for-all scrape:
- [ ] You must register for an API key and accept TfL's specific Open Data terms and conditions before use — not optional, and TfL states plainly that if you don't agree to the terms, you must not use the data
- [ ] Attribution to TfL is required per their brand guidelines
- [ ] This is a proper API integration (Section 11-style), not scraping their website — use their Unified API, not their public pages

### 19.3 National Rail (Darwin feed) — free and open for your scale, with a cap

National Rail's Darwin real-time data moved to an open licence in 2014specifically so developers could build apps and tools with it, including commercial ones, without the previous licensing fees. The practical details:
- [ ] Registration required (a T&Cs acceptance, not a payment, at your scale)
- [ ] Free until a commercial app crosses roughly 5 million requests in a 4-week period — well beyond your 10K–1 lakh user range for the foreseeable future, so this is a non-issue at your stage but worth knowing about as you scale
- [ ] Use the official Darwin Webservice/Push Port feeds, not scraped National Rail Enquiries web pages

### 19.4 The general rule: APIs with published terms are fine; scraping web pages is not

This is the actual dividing line, and it's worth stating explicitly to your developer:
- **"Publicly visible" is not the same as "legally reusable."** A restaurant's phone number showing on a Google search result page doesn't mean you're free to scrape that page and store it — Google's terms govern that data regardless of where you encountered it, and scraping their pages directly (rather than using their API) is a clearer terms-of-service violation, and in the UK can also raise Computer Misuse Act 1990 concerns if it involves bypassing technical access controls.
- **Using an official API within its published terms is the safe path.** Every data source in this guide (Google Maps Platform, TfL, National Rail) has one — use it, respect its specific caching/storage rules, and you're on solid ground.
- **For data with no compliant API** (e.g. a specific restaurant's live availability that only exists on their own website), the legally clean approach is a direct partnership or a manually-maintained listing your team updates — not an automated scraper.

### 19.5 One more category worth flagging: personal data on drivers/individuals

If "cab drivers' information" means individual driver names/numbers rather than a taxi company's public business line, that's personal data under UK GDPR, and storing/displaying it needs its own lawful basis and the individual's awareness — this is different from a business's published contact number. For the app's actual use case, you almost certainly want **company-level taxi/private-hire firm listings** (already public business information) rather than individual driver data, which sidesteps this issue entirely.

### 19.6 Before launch

- [ ] Get a UK-qualified solicitor (even a short paid consultation) to review your final data-sourcing approach once it's built — this guide gets you to "architected correctly," not to "legally signed off"
- [ ] Keep a `data_source` and licence-reference column (as already in Section 17.3) on every table so you can prove, source by source, what terms governed each piece of data if ever asked
- [ ] Publish your own Terms of Use and Privacy Policy referencing Google's terms, as Google's Places policy itself requires of any app displaying their data

---

## 21. UK Taxi/Private-Hire Fare Data — What's Actually Official

Following the same rule from Section 19: check whether an official source exists before building anything, and link out rather than scrape when it doesn't.

### 21.1 London black cabs — genuinely official, safe to build from

TfL publishes the actual regulatory tariff structure for licensed London taxis (black cabs/hackney carriages) — this is public regulatory information, not scraped private content, so it's fine to use as the basis for your own fare estimate calculator:
- **Three tariffs**: Tariff 1 (Mon–Fri, roughly 06:00–20:00, standard day rate), Tariff 2 (evenings Mon–Fri and all-day weekends, higher rate), Tariff 3 (nightly ~22:00–06:00 and public holidays, highest rate — this is your "night charges" answer)
- **Minimum fare** and per-mile/per-minute rates are published on TfL's official taxi fares page and reviewed roughly annually
- [ ] Build your calculator from TfL's published tariff table (cite TfL as the source, link to their official page for the current exact figures) — but always frame it as an **estimate**, since the actual meter accounts for real-time traffic and exact route, which your static table can't replicate
- Private-hire vehicles (minicabs) in London are **pre-agreed price, not metered** — there's no tariff table to build from; the honest answer for these is "the operator confirms the price before you travel," not a calculator

### 21.2 Outside London — no single official body, no national fare API

This is the honest limitation: outside London, taxi/private-hire licensing is handled by **individual local councils**, each of which can set its own hackney carriage tariff. There is no single national taxi fare authority or public API covering all of England/Scotland/Wales/NI.
- The one national database that does exist — **NR3S**, run by the Local Government Association/National Anti-Fraud Network — only contains licence **refusals and revocations** for safeguarding purposes. It's not a fare database and isn't a public API for app developers to query.
- [ ] For cities outside London, the right approach is exactly what you said: **link out** to the official channel rather than scrape — either the local council's published tariff page (if one exists) or, more practically, the ride-hailing apps themselves (Uber, Bolt) which show a live fare estimate through their own apps before booking
- [ ] Where you're not sure whether a given council or local taxi firm's page can be used, the safe default is the same principle as Section 19: **link to it, don't scrape it** — and if a specific case is genuinely ambiguous, that's a "flag it and ask" situation rather than a "guess and proceed" one, exactly as you said

---

## 22. Admin-Only Reference: Affiliate/Partner Programs (Not for User-Facing Display)

**This section is for your business/dev team only — never surface commission rates, partner names framed as "sponsored," or this table itself in the user-facing app.** Users should just see a normal-looking link to Booking.com, Uber, etc.; which of those pay you a commission is your business's internal information, not something to disclose in-app (beyond whatever generic affiliate-disclosure language your legal/compliance sign-off from Section 19.6 requires you to include somewhere in your terms).

| Partner | Program type | What triggers a payout | Typical rate (verify current terms before relying on this) |
|---|---|---|---|
| Booking.com | Affiliate (via Awin network) | Completed hotel stay | ~4% of accommodation booking value |
| TripAdvisor | Affiliate (via Awin/CJ/Travelpayouts) | Click-through from your site to their booking partners — **no booking required**, just the click-out | Minimum 50% revenue share on the click-out value (typically £0.24–£0.40 per click, so volume matters more than rate here) |
| Trainline | Affiliate (via Awin/FlexOffers) | Completed ticket sale | Rate not publicly fixed — apply and check your dashboard |
| Uber / Uber Eats | Uber's own affiliate program | First trip or first order from a referred new user (acquisition-focused, not ongoing) | Rate negotiated per-partner, not publicly fixed |
| Wise, Revolut | Referral/partner programs (both actively run one) | Varies — typically new account sign-up or first transaction | Check their current partner/referral pages directly — these change often |
| Deliveroo, Just Eat, Foodhub | Likely available via affiliate networks (Awin/CJ) for driving new customers | New customer acquisition, typically | Not confirmed publicly — apply directly to check |

**How to use this table:** it's a starting checklist for someone on your team to actually apply to each program and confirm current rates — treat every number here as "last verified via search, re-check before building commission logic around it," not as contract terms. Once confirmed, store the actual agreed rate and tracking link format in your own internal `partners` table (not hardcoded in app code, since rates and links change).

```sql
-- Admin-only table, never exposed via any user-facing API endpoint
partners
  id UUID PRIMARY KEY
  partner_name VARCHAR
  program_type VARCHAR         -- 'affiliate_network', 'direct_referral'
  tracking_link_template VARCHAR
  commission_notes TEXT        -- rate, payout trigger, last verified date
  is_active BOOLEAN
```

This keeps monetization data cleanly separated from your public API and content tables — the same `country_code`-tagged `listings` a user sees can carry a `partner_id` foreign key behind the scenes, so a restaurant or booking link resolves to the right tracked affiliate URL without any of this ever being queryable by a user-facing endpoint.

---

## 24. Admin-Only Research: Transport Aggregators & Discount Coach Operators

One name in your message I want to flag honestly: I couldn't confidently identify what "kirko" refers to — if you meant a specific site, let me know and I'll dig into that one specifically. What follows is solid research on the ones I could clearly identify from your message: **Rome2Rio** (you called it "Romeo") and the discount coach space around **FlixBus**.

### 24.1 Rome2Rio / Omio — how the "one search, all transport" model actually works

Rome2Rio is the site you're describing: a single search box that returns every way to get from A to B — flights, trains, buses, ferries, driving, even walking — pulled from thousands of operators worldwide. A few things worth knowing:
- **It was acquired by Omio in 2019** (Omio itself is Europe's leading multi-modal *booking* platform — Rome2Rio does the route/price discovery, Omio does the actual ticket sale). They now operate as one group.
- **Revenue model**: affiliate commission on bookings made through the platform, advertising, and paid "premium listing" placement for transport/accommodation partners who want better visibility in the results — the same three levers you already have in your Section 9 monetisation plan.
- **It doesn't build its own timetables from scratch** — it integrates with thousands of operators' own data feeds/APIs. This is the part worth knowing for your build: Rome2Rio historically offered developers **free API access** to embed multi-modal route search into third-party sites. Worth checking their current developer terms directly — if that access still exists, it may be far cheaper for you to **embed Rome2Rio's route search inside your itinerary module** than to build your own multi-modal route engine from scratch, especially at your current stage.

### 24.2 FlixBus — the discount coach operator, and how UK coach discounts work generally

FlixBus is the coach company you're describing — cheap, wide UK/Europe coverage, grown rapidly by **partnering with existing local coach operators** rather than only running its own fleet (e.g. it's added Stanley Travel, Bouden Coach Travel, McGills, and others as network partners, all rebranded under the FlixBus app). This partnership model — a tech/booking layer sitting on top of multiple existing operators' fleets — is structurally similar to what Rome2Rio/Omio do, just narrower (coach only) and vertically integrated with actual fleets.

**The discount landscape you're asking about, concretely:**
| Discount | How it works | Who qualifies |
|---|---|---|
| FlixBus student discount | ~11–25% off via student verification apps (Studentbeans/UNiDAYS) — the discount % varies by country | Students |
| National Express Young Persons Coachcard | ~1/3 off, £15/year (or £35 for 3 years) | Under a certain age, National Express only — doesn't work with other operators |
| National Express student discount (no card) | Up to 25% off full-price fares | Students, no card needed |
| megabus + TOTUM card | 10% off | Students with a TOTUM card |

**What this means for your itinerary module:** these discounts are card/verification-gated, not something your app can apply automatically — but you can absolutely **surface them as advice** ("if you have a student card, National Express and megabus both offer discounts — here's how") as genuinely useful content, separate from any affiliate link you're also including.

### 24.3 How UKPath should actually be different from Rome2Rio/Omio/FlixBus/Skyscanner

This is the important strategic point, not just a feature comparison: **you are not trying to out-build Rome2Rio's global route engine, and you shouldn't try to.** These platforms compete on breadth (every route, every operator, everywhere) and pure price comparison, aimed at a general global audience. That's a genuinely hard, capital-intensive thing to replicate, and it's not your actual gap in the market (Section 5 already identified the real gap: nobody serves the *Indian visitor specifically*, with cultural context, first-time guidance, and everything bundled — not just transport).

**The right positioning:** UKPath sits **above** these tools as a curation and context layer, not beside them as a competitor:
- For the actual route search/booking, **deep-link or embed** Rome2Rio/Trainline/FlixBus rather than rebuilding their engines (per Section 24.1's API note)
- What you add on top is what none of them do: "you're landing at Heathrow from Delhi, here's what a first-timer should know, here's the realistic cost and time to get to Swindon, here's the student/other discount you might not know about, here's what to do if something goes wrong" — the anxious-first-arrival guidance layer from Sections 14–15
- This also directly answers your monetisation question from Section 9/22: you earn the same way Rome2Rio does (affiliate commission on the bookings you route through) without needing to build what Rome2Rio spent over a decade building

### 24.4 Does Rome2Rio pay *you* for linking to them? (Direct answer: no confirmed program)

I checked specifically, since this changes what's worth building. Rome2Rio's own revenue comes from the *other* direction: when someone searches on Rome2Rio and clicks through to book, Rome2Rio earns a commission from **its own booking partners** — Skyscanner for flights, Booking.com for hotels, Rentalcars.com for cars. I found no public affiliate or referral program where Rome2Rio pays third-party sites like yours for sending them traffic. What they do offer commercially is a **Partner API / White Label program** (a paid or free-tier licensing product, via their partner dashboard) — that's a cost or a data-access deal, not a revenue source from linking out.

**What this means for your "just add the link" plan:**
- [ ] Adding a plain "want to compare more routes? Search on Rome2Rio" link is completely fine and genuinely useful to the user — but it earns UKPath nothing directly, since Rome2Rio isn't paying you for the click
- [ ] **The better version of the same idea**: rather than routing through Rome2Rio, link directly to the operators you already have affiliate relationships with from Section 22 — Trainline, Booking.com, Uber — for the specific leg of the journey you're showing. You get the "here's another option to check" value for the user without giving up the commission to an intermediary
- [ ] Keep the Rome2Rio-style link as a **secondary, no-strings option** — "for a full multi-modal comparison, try Rome2Rio" — genuinely helpful, correctly labeled as non-monetized, and not something to build any tracking or integration around

---

## 26. A Simple, Traveler-First Architecture (Plain English, No Jargon)

You're describing something real: the modules in Section 4 ("Module A, Module B...") are how a *developer* thinks about the app. A traveler doesn't think in modules — they think in a timeline of worries. The cleanest fix is to rename and regroup the entire navigation around **what's on the traveler's mind at each moment**, not around your internal feature list.

### 26.1 The traveler's actual mental timeline

Put yourself in their shoes, landing at Heathrow for the first time:
1. **"Did I bring the right things? What don't I need to carry?"** — before landing
2. **"I've landed — what do I do right now?"** — the first hour
3. **"How do I get to where I'm staying?"** — the next few hours
4. **"How do I live day to day here?"** — food, money, phone, once settled
5. **"What if something goes wrong?"** — the thing they hope they never need, but need to find in seconds if they do

### 26.2 Renaming the navigation around that timeline, not your module list

| Old (developer-facing) | New (traveler-facing, plain English) | What lives here |
|---|---|---|
| Module A — Onboarding | *(just the sign-in screen, not a nav item)* | Login/guest mode |
| Module F — Itinerary Planning | **Before You Land** | Packing advice, pre-order groceries (Section 27), what to expect at your airport (Section 14) |
| Module C — Local Travel | **Getting to Your Stay** | Airport → destination routes (Section 15), fare estimates (Section 21) |
| Module B, D, E — Food, SIM, Money | **Living Here** | Food & grocery, SIM setup, money/card guidance |
| Module G — Writing Help | **Need Help Writing Something?** | Email/complaint templates |
| Module H — Emergency | **If Something's Wrong** | Always one tap away, never buried |
| Chat widget (Section 8) | **Chat With Us** | Visible everywhere, not hidden in a menu |

**The test for every screen name going forward:** would a first-time visitor, reading it out loud, immediately know what's behind it without thinking? "If Something's Wrong" passes that test. "Module H — Emergency & Safety Services" does not.

### 26.3 What this means for the home screen (ties back to the mockup in an earlier message)

Instead of a flat grid of 7 equal-sized category tiles, structure the home screen around the timeline itself:
- A single, prominent card at the top that changes based on *where the user is in their trip* — "Landing in 2 days? Order your groceries now" before arrival, "Just landed? Here's your route to Swindon" right after, "Need something right now?" once settled
- The category tiles (food, travel, SIM, money, etc.) sit below as the everyday toolbox, not competing with the one thing that's actually relevant *right now*
- Emergency stays as its own fixed, always-visible element (not a tile that scrolls away) — exactly the full-width treatment it already has in the mockup

---

## 27. Feature: Order Groceries Ahead of Landing (Corrected for How Delivery Actually Works)

One correction to the assumption in your message, based on checking how these services actually price delivery: **it depends entirely on the retailer — some do weight-tier pricing exactly like you're describing, others price by order value only.** I checked Shubham Foods UK's actual published rates directly, and they do exactly what you're asking for:

**Shubham Foods UK — real, current UK mainland rates:**
| Weight | Order value | Delivery cost |
|---|---|---|
| Up to 25kg (1 box) | £50+ | **£0** (free) |
| Up to 25kg (1 box) | Below £50 | **£5.99** |
| Under 2kg (small parcel, economy) | Any | £4.99 |
| Under 2kg (small parcel, express) | Any | £6.99 |
| 25–50kg (2 boxes) | Any | £11.98 |
| 50–75kg (3 boxes) | Any | £17.97 |
| 75–100kg (4 boxes) | Any | £23.96 |

**Note: Scotland has separate, higher rates** (starting at £15.99 for 0–25kg) — worth building this as a region-aware field, not a single UK-wide number.

So for your specific example — **up to 10kg fits entirely within their "up to 25kg" band**, meaning the delivery cost is just **£5.99 if the basket is under £50, or free if it's £50+** — it doesn't scale up between 0 and 25kg, it's a flat rate for that whole band. That's actually the honest, useful number to show a user: not a per-kg calculation (which would imply false precision), but "here's the real flat rate for the weight band your order falls into."

**Other retailers work differently** — Red Rickshaw and PickEasy publish a value-based free-delivery threshold (£50 and £40 respectively) without a public weight-tier breakdown, and Lakshmi Stores quotes up to 5 working days standard delivery (slower than the next-day figure I mentioned earlier — delivery speed genuinely varies by retailer, so this should be pulled per-retailer, not assumed uniform). This is exactly the kind of retailer-by-retailer variation Section 17's daily-refresh pipeline should track — a `delivery_policy` field per partner rather than one hardcoded number for "Indian grocery delivery."

### 27.1 The feature, built correctly

1. User enters their **arrival date** and **UK destination address** (Section 26's "Before You Land" screen)
2. App shows a curated, small list of common items (rice, dal, spices, snacks, ghee) rather than replicating a full retailer catalogue — this is a *starter kit* experience, not a full grocery app
3. App shows the **real delivery cost for the weight band and the real delivery speed, per retailer** — e.g. Shubham Foods' actual £5.99/free-over-£50 table above, or Lakshmi Stores' actual "up to 5 working days" if that's the retailer selected — never a single averaged number across retailers, since the Section 27 research shows speed and pricing genuinely differ (next-day for some, up to 5 days for others)
4. Because delivery speed varies this much by retailer, the app's "order by this date" suggestion should be **retailer-specific**, not one fixed rule — a next-day retailer selected 1 day out is fine; a 5-day retailer selected 1 day out should visibly warn the user it likely won't arrive in time
5. User is deep-linked out to complete the actual purchase on the retailer's own site (this is an affiliate-link opportunity exactly like Section 22 — check if Veena's, Red Rickshaw, etc. run an affiliate program before assuming one exists, same rule as Section 24.4)

### 27.2 The one real-world catch worth flagging before you build this

**Hotels don't always accept deliveries addressed to a guest who hasn't checked in yet**, and even when they do, some charge a holding fee or won't take responsibility for it. This is worth surfacing to the user directly rather than letting them find out the hard way:
- [ ] Add a simple note on this screen: "Check with your hotel that they'll accept a delivery before you check in — most will, but it's worth a quick call first"
- [ ] Default the suggested delivery date to **the day of arrival or the day after**, not before — safer than assuming a pre-arrival delivery will be accepted
- [ ] For guests staying with family/friends rather than a hotel, this whole caveat disappears — worth asking which applies before showing the delivery-date suggestion

---

## 28. Feature Update: UKPath's Own Grocery Packing & Delivery (Swindon Hub), Plus Third-Party Store Links

This is a bigger shift than it might look like: instead of only linking out to third-party retailers, **UKPath itself becomes the seller** — packing groceries from a Swindon base and shipping nationwide, with the third-party retailer links from Section 27 staying available as an alternative. That changes both the technical build and the legal/operational picture, so both are covered here.

### 28.1 One correction before designing the fare calculator: UK delivery pricing isn't really distance-based

Worth knowing before building this: UK domestic couriers (Royal Mail, DPD, Evri, Parcelforce) price mainland deliveries almost entirely by **weight and speed**, not by distance — sending a 10kg box from Swindon to Bristol costs about the same as sending it to Edinburgh, because mainland UK is treated as one flat pricing zone by every major courier. Distance only matters at the edges: **the Scottish Highlands & Islands, and Northern Ireland, carry a real surcharge** from every courier (this is exactly the pattern you already saw in Shubham Foods' own rate card in Section 27 — flat mainland UK rates, then a separate, higher Scotland table).

**So the "rough fare from Swindon" is best built as:**
- A flat, weight-tiered rate for UK mainland (same style as Shubham Foods' table — e.g. up to 5kg, 5–10kg, 10–25kg bands, one price per band regardless of whether the destination is Bristol or Newcastle)
- A separate, higher rate band for the Scottish Highlands/Islands and Northern Ireland (postcode-detected, not distance-calculated)
- This is simpler to build than a true distance calculator, and more accurate to how couriers actually charge you — a real distance-based number would misrepresent your actual cost, which is the thing this feature needs to reflect since you're the one paying the courier

### 28.2 The ordering flow

1. **Predefined item catalogue** — a curated list you stock and pack yourself (start small: rice, dal, spices, snacks, ghee — the "starter kit" items from Section 27, not a full supermarket range)
2. User builds a basket from this list; running weight total shown as they add items
3. **Delivery fare** looked up from the weight-band table (Section 28.1) plus a remote-postcode surcharge flag, calculated the moment the user enters their delivery postcode — not a manual quote
4. Checkout — payment, delivery address, requested delivery/arrival date
5. **Alongside this flow, the third-party store options from Section 27 still show as an alternative** — "or order from these other UK stores directly" — exactly as you said, with their phone number and minimum order value visible for comparison

### 28.3 Schema for the item catalogue and fare bands

```sql
-- Your own stocked items (distinct from third-party `listings`)
grocery_items
  id UUID PRIMARY KEY
  name VARCHAR
  category VARCHAR         -- 'rice', 'spices', 'snacks', etc.
  price DECIMAL
  weight_grams INT
  in_stock BOOLEAN

-- Weight-banded delivery fares from your Swindon hub
delivery_fare_bands
  id UUID PRIMARY KEY
  min_weight_grams INT
  max_weight_grams INT
  mainland_uk_fare DECIMAL
  highlands_islands_ni_fare DECIMAL

-- Third-party store directory (extends the `listings` table from Section 2)
-- add these columns specifically for this comparison view:
ALTER TABLE listings ADD COLUMN phone_number VARCHAR;
ALTER TABLE listings ADD COLUMN minimum_order_value DECIMAL;
ALTER TABLE listings ADD COLUMN typical_delivery_speed VARCHAR;  -- 'next-day', 'up to 5 days', etc.
```

### 28.4 Important: this makes UKPath a food business, not just a directory app

This is worth being direct about, because it changes your legal obligations in a real way compared to everything else in this guide so far (which was consult-only/directory/affiliate — no handling of physical goods). Once UKPath packs and ships food itself:
- [ ] **Food business registration** with your local council is a legal requirement in the UK, at least 28 days before you start trading — this applies even to a small packing operation
- [ ] **Allergen information** must be clearly provided for every item sold — this is a legal requirement (Food Information Regulations), not optional labelling
- [ ] You'll need an actual **courier account** (Royal Mail Click & Drop, DPD, Evri Business, etc.) — the fare bands in Section 28.1 should reflect your real negotiated rates once you have one, not just published retail rates
- [ ] Basic **food hygiene practices** for whoever is doing the packing (a Level 2 Food Hygiene certificate is the common baseline, even for packing rather than cooking)
- [ ] This is a good candidate for the same "get it checked before launch" step as Section 19.6 — a UK food business registration is genuinely quick and cheap to sort out properly, and far cheaper to do before you start selling than after

---

## 29. Code-Enforced Compliance Gate (Not Just a Checklist)

Everything in Sections 19, 21, and 28.4 has been checklist-style so far — good for planning, but a checklist can quietly get skipped under launch pressure. Here's the fix you asked for: make legal sign-off a **hard gate in the code itself**, so the feature literally cannot go live until someone has actually flipped it.

### 29.1 A `compliance_approvals` config table

```sql
compliance_approvals
  id UUID PRIMARY KEY
  approval_key VARCHAR UNIQUE   -- 'food_business_registered', 'courier_licence_confirmed', etc.
  is_approved BOOLEAN DEFAULT false
  approved_by VARCHAR           -- name of the person who signed off, not a developer
  approved_at TIMESTAMP
  evidence_note TEXT            -- e.g. "council reg number 12345, confirmed via email 12/03"
```

Seed it with every approval this guide has flagged, all defaulted to `false`:
- `food_business_registered` (Section 28.4)
- `allergen_labelling_reviewed` (Section 28.4)
- `courier_account_active` (Section 28.4)
- `food_hygiene_cert_obtained` (Section 28.4)
- `solicitor_data_review_complete` (Section 19.6)
- `emergency_numbers_human_verified` (Section 11's warning that this category should never be automated)

### 29.2 The actual code-level gate

```javascript
// Server-side check, not a UI-only warning — this must block the API endpoint itself
async function canEnableGroceryCheckout() {
  const required = ['food_business_registered', 'allergen_labelling_reviewed', 'courier_account_active', 'food_hygiene_cert_obtained'];
  const approvals = await db.compliance_approvals.findAll({ where: { approval_key: required } });
  return required.every(key => approvals.find(a => a.approval_key === key)?.is_approved === true);
}

// In the checkout route itself:
app.post('/grocery-checkout', async (req, res) => {
  if (!(await canEnableGroceryCheckout())) {
    return res.status(503).json({ error: 'This feature is not yet available.' });
    // NOTE TO DEVELOPER: do not bypass this check or hardcode it to true.
    // It only becomes true when compliance_approvals rows are updated by
    // someone with actual authority to confirm council/legal sign-off —
    // not by a developer during testing.
  }
  // ... proceed with order
});
```

**The point of building it this way**: a developer testing locally, or a future team member unfamiliar with the legal background, cannot accidentally ship the grocery-checkout feature to production — it's structurally blocked until the actual approvals exist as rows in the database, entered by someone who did the real-world registration, not by anyone editing code. This is a small amount of extra work that removes a real risk.

---

## 30. Feature: Personal-Shopper Courier Model (Buying Groceries on the Customer's Behalf)

This is a different, and genuinely simpler-to-license, model than Section 28's "UKPath stocks and ships its own groceries" — worth building as a clearly separate flow, not a variant of the same one.

### 30.1 How this is different from Section 28

Instead of UKPath holding its own stock, a UKPath courier (staff or a gig worker) **physically goes to an existing Indian grocery store, buys the items the customer requested, and delivers them.** This is the same underlying model as Deliveroo/Uber Eats/Instacart — you're not the retailer of the goods, you're the purchasing-and-delivery agent, and it sidesteps Section 28.4's food-business-registration requirement entirely, since you're not manufacturing, packing, or selling food as a retailer — the grocery store remains the seller of record.

### 30.2 Payment handling — an important distinction from Section 7's "no money handling" rule

This is worth being precise about, since Section 7 established "no money handling" as a legal boundary for the Money module (to stay outside FCA e-money regulation). **This is a different kind of money handling, and it's the common, already-legal kind**: taking payment for a purchase-and-delivery service (exactly what Deliveroo/Uber Eats/Instacart already do) is not the same as issuing or managing e-money/prepaid balances. You're charging for a service (buying + delivering), not operating a payment or card product. That said, get this specific point confirmed as part of Section 19.6/29's legal sign-off — don't take my summary as the final word, since the exact structure (do you take payment before or after buying, do you mark up prices, etc.) affects the details.

**A practical flow that keeps this clean:**
1. Customer selects items from a list (can be the same predefined-item UI as Section 28.2) and a target store
2. App shows an **estimated total** (item prices + a clearly stated service/delivery fee) and takes an **authorization** for that estimated amount, not a final charge
3. Courier buys the actual items, keeps the receipt
4. Final charge is settled against the real receipt total plus the service fee — refund the difference if items were unavailable/substituted, charge the difference (with the customer's prior consent to a reasonable range) if it came in higher
5. [ ] **Substitution policy needs to be explicit and shown to the customer up front** — what happens if an item's out of stock (courier picks a substitute? skips it? asks the customer first via chat?) — this is the single most common source of complaints in this business model, worth designing deliberately rather than leaving implicit

### 30.3 Schema addition

```sql
shopper_orders
  id UUID PRIMARY KEY
  user_id UUID REFERENCES users(id)
  store_listing_id UUID REFERENCES listings(id)
  requested_items JSONB          -- what the customer asked for
  estimated_total DECIMAL
  actual_total DECIMAL           -- filled in after the courier shops
  service_fee DECIMAL
  substitution_notes TEXT
  status ENUM('requested','shopping','out_for_delivery','delivered','cancelled')
  courier_id UUID                -- references a `couriers` table (staff or gig workers)
```

### 30.4 This adds a new compliance flag, not a replacement for Section 28's

Add to the `compliance_approvals` table from Section 29: `personal_shopper_payment_model_reviewed` — even though this model is generally simpler to license than Section 28's, it should go through the same sign-off gate before its checkout endpoint goes live, for the same reason: a real person with authority confirms it, not a developer assuming it's fine.

---

## 31. Payment Gateway — the Easiest One to Manage

You need a real payment processor for two things that have come up: the grocery checkout (Section 28) and the personal-shopper model's authorize-then-settle flow (Section 30). Here's a direct recommendation, checked against current UK pricing.

### 31.1 Recommendation: Stripe

For "easy to manage" specifically, **Stripe is the right pick**, for a few concrete reasons:
- **No monthly fee, no setup fee, no cancellation fee** — you only pay per transaction, which matters at your current scale
- **Current UK fees**: 1.5% + 20p per transaction for standard UK-issued cards, 1.2% + 20p if using their "Link" one-click checkout, higher (2.5–3.5% + 20p) for EU/international cards — transparent, published, no hidden charges
- **Built-in support for exactly the flow Section 30 needs**: Stripe's "manual capture" mode lets you *authorize* a card for an estimated amount, then *capture* the actual final amount later (up to 7 days later) once your courier knows the real total — this is a native feature, not something you'd have to build yourself
- **Genuinely easy Node.js integration** — a mature, well-documented SDK (`npm install stripe`), widely used, so hiring a developer who already knows it is easy
- **PCI compliance is handled for you** — Stripe is a Level 1 PCI DSS provider, meaning you never touch or store raw card numbers yourself, which keeps you out of a whole category of security obligation

### 31.2 Where the alternatives fit instead

| Option | When it's the better pick |
|---|---|
| **PayPal** | Some users trust/prefer paying via PayPal specifically — worth offering *alongside* Stripe as a second option, not instead of it, since offering both costs nothing extra and removes a checkout objection for PayPal-preferring users |
| **Wise Business** | Useful later if you start receiving payments in other currencies (e.g. from an India-based arm of the business), not a card-payment gateway itself |
| **Square** | Better fit if you also plan in-person payments (e.g. a physical counter) — not relevant to UKPath's current online-only model |

### 31.3 What to hand the developer

- [ ] Set up a Stripe account under the registered UK business entity (needs the food-business/courier registration from Sections 28.4/30 to be far enough along to have a business bank account to connect)
- [ ] Use **Stripe Checkout** (their pre-built hosted payment page) rather than building a custom card form — faster to ship, and Stripe keeps it PCI-compliant and updated automatically
- [ ] Use **manual capture mode** specifically for the Section 30 personal-shopper flow; standard automatic capture is fine for the Section 28 fixed-catalogue checkout, since the price is known upfront
- [ ] Add PayPal as a second checkout option once the core Stripe flow is working — not a launch blocker, a nice-to-have

### 31.4 The gap this section missed: paying your couriers, not just charging customers

Section 31 so far only covers taking money *from* the customer. Section 30's personal-shopper model also needs to pay *out* to whoever does the actual shopping and delivery — staff or gig workers. That's a different Stripe product:
- **Stripe Connect** is built exactly for this — a marketplace-style setup where money comes in from customers and a share of it flows out to couriers, with Stripe handling the split, the payout schedule, and each courier's own tax/identity verification (know-your-customer checks), rather than you building payout logic and compliance yourself
- [ ] Each courier gets their own "connected account" under your main Stripe account; you decide the split (e.g. service fee kept, rest paid to courier) programmatically per order
- [ ] This is meaningfully more setup than a plain checkout, so budget real time for it — it's the right tool, just not a five-minute addition

### 31.5 Subscriptions (for the Premium tier in Section 9)

Your monetisation plan already includes a premium subscription (offline guides, priority support). Stripe's separate **Billing** product handles recurring charges, proration, and cancellation — don't try to build recurring billing logic by hand on top of one-off Checkout; it's a different, purpose-built API (`stripe.subscriptions`) that plugs into the same account.

### 31.6 One compliance note specific to card payments: Strong Customer Authentication

UK card payments are legally required to use **Strong Customer Authentication (SCA)** — the "verify with your bank app" or SMS-code step you've likely seen on other sites — for most online card transactions. Stripe Checkout and Stripe Elements handle this automatically as part of the standard flow, so this isn't extra work for your developer, but it's worth knowing it's a legal requirement (under the UK's Payment Services Regulations), not just a Stripe design choice — don't let anyone "simplify" the checkout by trying to bypass it.

### 31.7 A genuinely cheaper option worth adding: Pay by Bank (Open Banking)

Fair pushback — and there is a real, current answer to it, not just "card fees are what they are." UK **Open Banking "Pay by Bank"** payments (via **GoCardless**, the most established provider) skip the card networks (Visa/Mastercard) entirely, moving money directly bank-to-bank instead — and that's exactly why it's cheaper:
- **GoCardless Instant Bank Pay: 1% + £0.20 per transaction, capped at a maximum £4** — no matter how large the order. Compare that to Stripe's 1.5% + 20p with no cap: on a £150 grocery order, Stripe costs you ~£2.45, GoCardless costs ~£1.70; the gap grows further on bigger orders since GoCardless's fee is capped and Stripe's isn't
- No chargebacks, and money typically lands in your account within seconds via UK Faster Payments, rather than Stripe's standard payout delay
- The customer pays by logging into their own bank's app to authorise the payment — no card number typed at all

**The one honest catch for your specific audience:** Open Banking payments move money from a UK bank account to a UK bank account — it doesn't work with an Indian-issued card, and a first-time visitor paying for groceries *before* they've landed almost certainly doesn't have a UK bank account yet. So this is the cheaper option for **repeat customers who've since opened a UK account** (a student who's been here a term, for example), but it can't be your only payment method — international cards still need to work for the pre-arrival use case that's the whole point of Section 27/28, and that means keeping Stripe (or another card processor) as the default.

**Recommended setup**: Stripe for card payments (works with Indian-issued cards, so it covers every customer including pre-arrival), with GoCardless's Pay by Bank offered as a cheaper alternative once you're serving repeat, UK-based customers — same "offer both" logic as PayPal in Section 31.2, just added for cost rather than preference.

---

## 32. Stripe's Business Account Prerequisite — What's Actually Required

Going with Stripe means going through their UK "Know Your Business" (KYB) verification before any money can move — this isn't optional paperwork, Stripe will restrict payouts until it's done. I checked their current UK requirements directly, here's the real list:

**What you need before starting Stripe onboarding:**
- [ ] **Companies House registration** — your business needs to actually be an incorporated UK company (or registered sole trader/partnership) with a Company Registration Number (CRN) first; Stripe checks this directly against Companies House
- [ ] **Registered business address** — a real address, not a PO box
- [ ] **UK business bank account** — sort code and account number, in the business's name (this is where payouts land)
- [ ] **Director/owner identity verification** — a valid passport or national ID for whoever is the legal representative/director, plus proof of address
- [ ] **Ultimate Beneficial Owner (UBO) details** — anyone owning more than 25% of the business needs to be declared and verified too
- [ ] **Business details**: phone number, email, website, and — if you're a limited company or sole trader — a tax document with your Unique Taxpayer Reference (UTR)
- [ ] **For Stripe Connect specifically** (needed for Section 31.4's courier payouts): each connected courier also goes through their own lighter-weight identity verification before Stripe will pay them out

**The dependency chain, stated plainly**: you can't get the UK business bank account and Companies House registration *for* Stripe until the company itself is properly incorporated — so this sits downstream of the same business-formation step that Sections 28.4 and 30 already required for food/courier registration. Get the company incorporated first; Stripe, the food registration, and the courier account can all then proceed from that same foundation.

### 32.1 Add this as its own compliance gate

Extend the `compliance_approvals` table from Section 29 with: `stripe_business_kyb_verified` — defaulted to `false`, same rule as everything else — the payment checkout code should check this flag exactly like Section 29.2's example, so no developer can accidentally point a checkout flow at a Stripe account that hasn't actually cleared verification.

---

## 33. Master Prerequisites & Documents Checklist (Everything We've Discussed, in One Place)

You're right that this has gotten large — this section exists specifically to answer "closely, what are the legalities for each different section" without making someone hunt through 32 sections. Every row below feeds into the same `compliance_approvals` table from Section 29, so this table **is** the seed data for that table.

| # | Requirement | Why (which section) | What's actually needed | `compliance_approvals` key |
|---|---|---|---|---|
| 1 | UK company incorporation | Foundation for everything below | Companies House registration, CRN | `company_incorporated` |
| 2 | UK business bank account | Stripe payouts, general trading | Sort code + account number in company name | `business_bank_account_active` |
| 3 | Stripe KYB verification | Section 32 | Director ID, UBO details, tax reference | `stripe_business_kyb_verified` |
| 4 | Food business registration | Section 28.4 | Local council registration, ≥28 days before trading | `food_business_registered` |
| 5 | Allergen labelling review | Section 28.4 | Per-item allergen info matching Food Information Regulations | `allergen_labelling_reviewed` |
| 6 | Food hygiene certification | Section 28.4 | Level 2 Food Hygiene cert for packing staff | `food_hygiene_cert_obtained` |
| 7 | Courier/delivery account | Section 28 | Business account with Royal Mail/DPD/Evri etc. | `courier_account_active` |
| 8 | Personal-shopper payment model review | Section 30.2 | Legal confirmation this isn't e-money/FCA-regulated | `personal_shopper_payment_model_reviewed` |
| 9 | TfL Open Data registration | Section 19.2 | API key, T&Cs acceptance | `tfl_open_data_registered` |
| 10 | National Rail Darwin registration | Section 19.3 | Developer T&Cs acceptance | `national_rail_registered` |
| 11 | Google Maps Platform account | Section 12 | Billing account, API key | `google_maps_account_active` |
| 12 | ICO registration (data protection fee) | New — see 33.1 below | Annual fee paid, registration number | `ico_registered` |
| 13 | Privacy Policy & Terms of Use published | Section 19.6 | Legal document referencing every third-party data source's terms | `privacy_policy_published` |
| 14 | Solicitor review of data-sourcing approach | Section 19.6 | Sign-off from a UK-qualified solicitor | `solicitor_data_review_complete` |
| 15 | Emergency numbers human-verified | Section 11 | Manual review, never automated | `emergency_numbers_human_verified` |

### 33.1 One requirement not yet covered: ICO registration

Worth adding since you asked me to check closely: most UK businesses that process personal data — which UKPath does the moment it has user accounts, delivery addresses, and order history — are legally required to **register with the Information Commissioner's Office (ICO)** and pay the annual data protection fee (a tiered fee based on company size, typically a modest amount for a small business), unless a specific exemption applies. This is separate from GDPR compliance itself (which Section 7 already covers) — it's a distinct registration/fee obligation. Add it to the list above and get it confirmed as part of the same solicitor review in row 14.

### 33.2 How to keep this from becoming unmanageable as the guide grows

Fair warning taken — this file is genuinely large now. The practical fix, when you're ready for it: **split this single document into a `docs/` folder that mirrors the module structure in Section 34 below** — one file per module (`payments.md`, `transport.md`, `grocery.md`, `compliance.md`, etc.) — with this file becoming a short index that links to each. I can do that restructuring whenever you want it; for now everything stays in one place so nothing gets lost while the plan is still taking shape.

---

## 34. Building This as a Truly Modular System (Plug-In, Not Tangled)

This is the most important structural instruction to give your developer, and it deserves to be explicit rather than assumed. The goal: **Payments, Transport, Grocery, SIM, Money Guidance, Emergency, Chat — each one is its own self-contained module that can be built, tested, replaced, or unplugged without touching the others**, and they all connect to one main site through clean, narrow interfaces.

### 34.1 The right pattern for your stage: a "modular monolith," not microservices

Section 9 already advised against jumping to microservices before you have a measured reason to — that advice still holds. The way to get "swap modules independently" **without** the operational cost of running ten separate deployed services is a **modular monolith**: one deployed application, but internally organized so the module boundaries are as strict as if they were separate services. This gets you the plug-and-play property you're asking for now, and makes it genuinely easy to split any one module into its own real microservice later, specifically because the boundary was already clean.

### 34.2 The concrete rule for your developer

**Every module gets its own folder, and modules only talk to each other through an explicitly exported interface — never by reaching directly into another module's database tables, internal functions, or files.**

```
/src
  /modules
    /payments          <- Section 31/32: Stripe, GoCardless, Stripe Connect
      index.js          <- the ONLY file other modules are allowed to import from
      stripe-provider.js
      gocardless-provider.js
      db-models.js       <- payments' own tables; nobody else touches these directly
    /transport          <- Sections 14-15, 21: routes, fares, flight data
      index.js
      route-lookup.js
      fare-calculator.js
    /grocery-catalog     <- Section 28: UKPath's own stocked items + Swindon fulfilment
      index.js
      catalog.js
      fare-bands.js
    /grocery-shopper      <- Section 30: personal-shopper courier model
      index.js
      shopper-orders.js
    /sim-guidance
    /money-guidance
    /emergency
    /chat                 <- Section 8: Tawk.to integration
    /compliance            <- Section 29/33: the approvals gate every other module checks
      index.js
      approvals.js
  /api                    <- the routes the app/website actually call
    grocery-routes.js      <- imports from modules/grocery-catalog and modules/payments,
                               never reaches into their internals directly
```

### 34.3 What "only talk through `index.js`" actually buys you

- **Swapping Stripe for another processor later** means rewriting `payments/stripe-provider.js` and `payments/index.js` — nothing in `grocery-routes.js` or any other module needs to change, because they only ever called the interface, never Stripe directly
- **A developer working on the transport module can't accidentally break payments** — there's no code path that lets them reach in and touch payment tables, because the folder boundary is enforced by what's exported, not just convention
- **Testing gets easier** — each module can be tested in isolation by mocking the narrow interface of the modules it depends on, rather than needing the whole system running
- **If Section 34.1's monolith ever needs to become real microservices** (once you're well past 1 lakh users and have a measured reason), the module boundaries in this structure map almost directly onto service boundaries — this is the concrete payoff of doing it this way now

### 34.4 The one discipline this requires from whoever's coding it

- [ ] Code review should explicitly check: "does this new code reach into another module's files/database directly, or does it go through that module's `index.js`?" — this is the rule that's easy to let slip under deadline pressure, and it's the whole point of the pattern
- [ ] Each module's `compliance_approvals` check (Section 29/33) lives inside that module, not scattered across the codebase — e.g. the grocery-catalog module checks `food_business_registered` internally before exposing its checkout function, rather than every caller having to remember to check it themselves

---

## 35. Open Questions to Resolve Before Coding

- React Native vs. Flutter — depends on your team's existing skills
- Will listings (restaurants, SIM shops) be manually curated or sourced via a partner API/feed?
- Who fulfills paid "service requests" (SIM setup help, itinerary planning) — human staff or automated?
- Target launch cities (London-only MVP, or nationwide from day one)?
