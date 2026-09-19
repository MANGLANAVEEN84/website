# UKPath — Compliance Guide

### Legal, Regulatory & Sign-Off Requirements — Separate from, but Gating, the Developer Build

This guide runs **side by side** with the [Developer Guide](../Dev/README.md), not before or after it. Developers can build every module in parallel with this checklist being worked through by the founder/business side and legal counsel. The two workstreams meet at one place: **a feature must not go live in production until its compliance items here are actually approved by a human with real authority — never defaulted to true by a developer.**

See the [Documentation Index](../README.md) for how this fits with the other docs.

---

## 1. Why This Is a Separate Document

The previous single developer guide mixed architecture decisions with legal requirements, which made it easy for a compliance item to get lost in a wall of technical detail — or worse, for a developer under deadline pressure to treat a `TODO: legal review` comment as optional. Splitting this out does two things:
1. Gives whoever is doing the legal/business work (you, or outside counsel) one document to track, without needing to read API specs
2. Lets the Developer Guide reference this doc by section anchor instead of duplicating legal text, so the legal wording only needs updating in one place

---

## 2. External Data Source Compliance

Every third-party data source the app touches has its own terms — "publicly visible" is not the same as "legally reusable." This is the actual dividing line for your developer: **using an official API within its published terms is fine; scraping web pages is not**, and in the UK scraping can also raise Computer Misuse Act 1990 concerns if it bypasses access controls.

### 2.1 Google Places API — restricted, not freely cacheable

- You may store a `place_id` indefinitely, and lat/lng for up to 30 days — **nothing else** (name, phone, hours, rating, photos) may be cached; it must be requested live at display time
- Store only `place_id` in the `listings` table; call Google Places live when a user views a listing
- Every screen showing Google Places data needs the Google logo/attribution per their display guidelines
- If you need a genuinely cacheable directory, evaluate **Geoapify** or **LocationIQ** (OpenStreetMap-based, permissive storage terms) instead

### 2.2 TfL Open Data — open, registration required

- Register for an API key and accept TfL's Open Data terms before use
- Attribution to TfL required per their brand guidelines
- Use the official Unified API, not scraped pages

### 2.3 National Rail (Darwin feed) — free at your scale

- Registration (T&Cs acceptance) required, no fee until ~5 million requests/4 weeks — well above 10K–1 lakh user range
- Use the official Darwin Webservice/Push Port feeds only

### 2.4 Personal data on individuals (e.g. taxi drivers)

- Individual driver names/numbers are personal data under UK GDPR and need their own lawful basis
- Use **company-level** taxi/private-hire firm listings (already public business info) instead — sidesteps this issue

### 2.5 Before launch

- [ ] UK-qualified solicitor review of the final data-sourcing approach (`solicitor_data_review_complete`)
- [ ] `data_source` and licence-reference column kept on every table sourcing external data
- [ ] Terms of Use / Privacy Policy published, referencing each third-party source's terms (`privacy_policy_published`)

---

## 3. Food Business Compliance (Sections 28/30 of the Developer Guide)

Once UKPath packs and ships its own groceries (Developer Guide's Swindon-hub feature), it becomes a food business, with real legal obligations that don't apply to the pure directory/affiliate parts of the app:

- [ ] **Food business registration** with the local council, ≥28 days before trading (`food_business_registered`)
- [ ] **Allergen information** on every item sold — legal requirement under Food Information Regulations, not optional (`allergen_labelling_reviewed`)
- [ ] **Courier account** (Royal Mail Click & Drop, DPD, Evri Business, etc.) with real negotiated rates (`courier_account_active`)
- [ ] **Food hygiene practice** — Level 2 Food Hygiene certificate as the common baseline for packing staff (`food_hygiene_cert_obtained`)

The **personal-shopper courier model** (buying from an existing store on the customer's behalf, not UKPath's own stock) sidesteps food-business registration since the grocery store remains the seller of record — but still needs its payment structure reviewed:
- [ ] Personal-shopper payment model (authorize-then-settle) confirmed as a purchase-and-delivery service, not e-money (`personal_shopper_payment_model_reviewed`)

---

## 4. Payments Compliance

- [ ] **Stripe UK KYB verification** — Companies House registration/CRN, registered business address, UK business bank account, director/owner ID verification, Ultimate Beneficial Owner (UBO) declarations for anyone owning >25%, business tax reference (`stripe_business_kyb_verified`)
- [ ] **Strong Customer Authentication (SCA)** — legally required under UK Payment Services Regulations for most online card transactions; handled automatically by Stripe Checkout/Elements — never let this be bypassed to "simplify" checkout
- [ ] The **Money module stays information-only** — no card issuance, top-ups, or balance display, which would tip the app into FCA-regulated e-money territory (this boundary is a design constraint the Developer Guide's Module E must respect, not a checkbox you tick after the fact)

---

## 5. Data Protection Compliance

- [ ] **ICO registration** and annual data protection fee — required once the app processes personal data (accounts, delivery addresses, order history), separate from GDPR compliance itself (`ico_registered`)
- [ ] UK GDPR: privacy policy, cookie consent (website), data deletion endpoint
- [ ] No storage of DOB, passport numbers, addresses beyond delivery use, or card numbers — enforced via schema design (see Developer Guide's data model), not just policy

---

## 6. Manual/Human-Verified Data

Some data categories must never be auto-updated by a scraper or refresh job, because a wrong value is a real-world safety risk:
- [ ] **Emergency numbers, visa/immigration facts** — human review only, on your own review schedule (`emergency_numbers_human_verified`)

---

## The `compliance_approvals` Table

This is the single source of truth the code checks — see the Developer Guide's module structure for where each module's check lives.

```sql
compliance_approvals
  id UUID PRIMARY KEY
  approval_key VARCHAR UNIQUE   -- e.g. 'food_business_registered'
  is_approved BOOLEAN DEFAULT false
  approved_by VARCHAR           -- name of the person who signed off, not a developer
  approved_at TIMESTAMP
  evidence_note TEXT            -- e.g. "council reg number 12345, confirmed via email 12/03"
```

### Master checklist (seed data for the table above)

| # | Requirement | `approval_key` |
|---|---|---|
| 1 | UK company incorporation | `company_incorporated` |
| 2 | UK business bank account | `business_bank_account_active` |
| 3 | Stripe KYB verification | `stripe_business_kyb_verified` |
| 4 | Food business registration | `food_business_registered` |
| 5 | Allergen labelling review | `allergen_labelling_reviewed` |
| 6 | Food hygiene certification | `food_hygiene_cert_obtained` |
| 7 | Courier/delivery account | `courier_account_active` |
| 8 | Personal-shopper payment model review | `personal_shopper_payment_model_reviewed` |
| 9 | TfL Open Data registration | `tfl_open_data_registered` |
| 10 | National Rail Darwin registration | `national_rail_registered` |
| 11 | Google Maps Platform account | `google_maps_account_active` |
| 12 | ICO registration (data protection fee) | `ico_registered` |
| 13 | Privacy Policy & Terms of Use published | `privacy_policy_published` |
| 14 | Solicitor review of data-sourcing approach | `solicitor_data_review_complete` |
| 15 | Emergency numbers human-verified | `emergency_numbers_human_verified` |

---

## Code-Enforced Compliance Gate

A checklist alone can quietly get skipped under launch pressure. Every module that touches money, food, or regulated data must check this table **server-side**, inside its own module boundary (see Developer Guide's modular-monolith structure) — not as a UI-only warning.

```javascript
// modules/compliance/approvals.js — the ONLY file other modules import from
async function isApproved(requiredKeys) {
  const approvals = await db.compliance_approvals.findAll({ where: { approval_key: requiredKeys } });
  return requiredKeys.every(key => approvals.find(a => a.approval_key === key)?.is_approved === true);
}
module.exports = { isApproved };

// Example use inside modules/grocery-catalog/index.js
const { isApproved } = require('../compliance/approvals');

app.post('/grocery-checkout', async (req, res) => {
  const required = ['food_business_registered', 'allergen_labelling_reviewed', 'courier_account_active', 'food_hygiene_cert_obtained'];
  if (!(await isApproved(required))) {
    return res.status(503).json({ error: 'This feature is not yet available.' });
    // NOTE TO DEVELOPER: do not bypass this check or hardcode it to true.
    // It only becomes true when compliance_approvals rows are updated by
    // someone with actual authority to confirm council/legal sign-off —
    // not by a developer during testing.
  }
  // ... proceed with order
});
```

**Rule for code review:** any PR that touches a checkout, payment, or personal-data endpoint should be checked for exactly one thing — does it call `isApproved()` for every relevant key before proceeding? If not, it doesn't merge, regardless of how complete the feature otherwise looks.

---

## How This Interacts With Testing

The [Testing Guides](../Test/) run against a **test environment** (see [Test Environment Guide §1](../Test/UKPath-Test-Environment-Guide.md#1-the-test-environment)) where `compliance_approvals` rows can be seeded to `true` for QA purposes only, so testers aren't blocked by real-world registrations that haven't happened yet. **This seed data must never exist in the production database or production deploy pipeline** — the [Production Deployment Guide's](../Prod/UKPath-Production-Deployment-Guide.md#2-promotion-path--test--production-only) promotion process explicitly excludes this table's data from any test→production sync.
