# UKPath — Module-by-Module Build Notes

### Section 4 & 7 of the Developer Guide

See the [Dev docs index](README.md) for how this fits with the other module docs.

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

## 7. Suggested Build Order (MVP → v1)

1. **MVP (6–8 weeks):** Onboarding, static Emergency module, static Itinerary templates, affiliate links for Money/SIM
2. **v1:** Food & Grocery directory, Writing templates, SIM comparison + guides, website with SEO content
3. **v1.1:** Paid service requests (itinerary planning, writing help), premium subscription, personalized itineraries
