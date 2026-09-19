# UKPath — Architecture & API

### Sections 1–3 of the Developer Guide — the shared backend contract every platform builds against

See the [Dev docs index](README.md) for how this fits with the other module docs, and the [top-level Documentation Index](../README.md) for the full map.

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

## Security & Compliance — See the Dedicated Guides

Technical controls and legal requirements are tracked by the people actually responsible for them, not mixed into this doc:
- **Technical controls** (TLS, JWT, rate-limiting, data handling, PCI scope) → [Security Guide](../Security/UKPath-Security-Guide.md)
- **Legal/regulatory sign-off** (GDPR, FCA scope, data-source terms, ICO registration) → [Compliance Guide](../Compliance/UKPath-Compliance-Guide.md)

No table stores DOB, passport, address, or card data — that's a schema-design rule enforced in Section 2 above, not just a policy note.
